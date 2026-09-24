//! Native navigation: loads Detour mesh-set binaries (the `MSET` format
//! the ingest writes, C-compatible layout) and answers the three runtime
//! queries — path finding, floor snapping and walkability — directly
//! through the upstream library.

use std::io::{Cursor, Read};

use byteorder::{LittleEndian, ReadBytesExt};
use rustler::{Binary, Error, ResourceArc};

const MSET_MAGIC: u32 = 0x4D53_4554; // "MSET"
const MSET_C_COMPAT_VERSION: u32 = 1;

// half extents of the nearest-poly query box: 2 across, 4 of height
const QUERY_EXTENTS: [f32; 3] = [2.0, 4.0, 2.0];
const MAX_PATH: usize = 2048;

// dtStatus bits (DetourStatus.h)
const DT_FAILURE: u32 = 1 << 31;

// -- C shim bindings --------------------------------------------------------

#[repr(C)]
struct NavMeshParams {
    origin: [f32; 3],
    tile_width: f32,
    tile_height: f32,
    max_tiles: i32,
    max_polys: i32,
}

#[allow(non_camel_case_types)]
type dtNavMesh = u8;
#[allow(non_camel_case_types)]
type dtNavMeshQuery = u8;
#[allow(non_camel_case_types)]
type dtQueryFilter = u8;
#[allow(non_camel_case_types)]
type dtPolyRef = u64;
#[allow(non_camel_case_types)]
type dtStatus = u32;

extern "C" {
    fn ms2_navmesh_create(params: *const NavMeshParams) -> *mut dtNavMesh;
    fn ms2_navmesh_destroy(mesh: *mut dtNavMesh);
    fn ms2_navmesh_add_tile(mesh: *mut dtNavMesh, data: *const u8, data_size: i32) -> dtStatus;
    fn ms2_navmesh_tile_count(mesh: *mut dtNavMesh) -> i32;
    fn ms2_navmesh_poly_count(mesh: *mut dtNavMesh) -> i32;
    fn ms2_query_create(mesh: *mut dtNavMesh, max_nodes: i32) -> *mut dtNavMeshQuery;
    fn ms2_query_destroy(query: *mut dtNavMeshQuery);
    fn ms2_filter_create() -> *mut dtQueryFilter;
    fn ms2_filter_destroy(filter: *mut dtQueryFilter);
    fn ms2_find_nearest_poly(
        query: *mut dtNavMeshQuery,
        center: *const f32,
        extents: *const f32,
        filter: *mut dtQueryFilter,
        out_ref: *mut dtPolyRef,
        out_point: *mut f32,
    ) -> dtStatus;
    fn ms2_find_path(
        query: *mut dtNavMeshQuery,
        start_ref: dtPolyRef,
        end_ref: dtPolyRef,
        start_pos: *const f32,
        end_pos: *const f32,
        filter: *mut dtQueryFilter,
        path: *mut dtPolyRef,
        path_count: *mut i32,
        max_path: i32,
    ) -> dtStatus;
    fn ms2_find_straight_path(
        query: *mut dtNavMeshQuery,
        start_pos: *const f32,
        end_pos: *const f32,
        path: *const dtPolyRef,
        path_count: i32,
        points: *mut f32,
        flags: *mut u8,
        refs: *mut dtPolyRef,
        point_count: *mut i32,
        max_points: i32,
    ) -> dtStatus;
    fn ms2_find_random_point_around_circle(
        query: *mut dtNavMeshQuery,
        start_ref: dtPolyRef,
        center: *const f32,
        max_radius: f32,
        filter: *mut dtQueryFilter,
        out_ref: *mut dtPolyRef,
        out_point: *mut f32,
    ) -> dtStatus;
}

fn failed(status: dtStatus) -> bool {
    status & DT_FAILURE != 0
}

// -- resources ---------------------------------------------------------------

// Detour meshes are read-only after their tiles are added and every query
// entry point is const — safe to share across scheduler threads
struct Nav(*mut dtNavMesh);

unsafe impl Send for Nav {}
unsafe impl Sync for Nav {}

#[rustler::resource_impl]
impl rustler::Resource for Nav {}

unsafe impl Send for Query {}

struct Query(*mut dtNavMeshQuery, *mut dtQueryFilter);

impl Drop for Query {
    fn drop(&mut self) {
        unsafe {
            ms2_filter_destroy(self.1);
            ms2_query_destroy(self.0);
        }
    }
}

impl Nav {
    fn query(&self) -> Result<Query, String> {
        let (query, filter) = unsafe {
            let query = ms2_query_create(self.0, 4096);
            if query.is_null() {
                return Err("navmesh query allocation failed".into());
            }
            let filter = ms2_filter_create();
            if filter.is_null() {
                ms2_query_destroy(query);
                return Err("query filter allocation failed".into());
            }
            (query, filter)
        };
        Ok(Query(query, filter))
    }
}

impl Drop for Nav {
    fn drop(&mut self) {
        unsafe { ms2_navmesh_destroy(self.0) };
    }
}

// -- nifs --------------------------------------------------------------------

/// Loads a mesh-set binary into a queryable mesh resource.
#[rustler::nif]
fn load_mesh(data: Binary) -> Result<ResourceArc<Nav>, Error> {
    let (params, tiles) =
        parse_mesh_set(&data).map_err(|reason| Error::RaiseTerm(Box::new(reason)))?;

    let mesh = unsafe {
        let mesh = ms2_navmesh_create(&params);
        if mesh.is_null() {
            return Err(Error::RaiseTerm(Box::new("navmesh allocation failed")));
        }
        for mut tile in tiles {
            let status =
                ms2_navmesh_add_tile(mesh, tile.as_mut_ptr(), tile.len() as i32);
            if failed(status) {
                ms2_navmesh_destroy(mesh);
                return Err(Error::RaiseTerm(Box::new(format!(
                    "tile rejected by the navmesh (status {status:#x})"
                ))));
            }
        }
        mesh
    };

    Ok(ResourceArc::new(Nav(mesh)))
}

/// The corridor of walkable points from `from` to `to`: the string-pulled
/// straight path through the polygon corridor, endpoints snapped onto the
/// mesh. Errors when either end has no walkable ground or no corridor
/// connects them.
#[rustler::nif]
fn find_path(
    nav: ResourceArc<Nav>,
    from: (f64, f64, f64),
    to: (f64, f64, f64),
) -> Result<Vec<(f64, f64, f64)>, String> {
    find_path_impl(&nav, to_pos(from), to_pos(to))
}

/// The closest walkable surface point, or an error when nothing walkable
/// sits within the query box.
#[rustler::nif]
fn snap(nav: ResourceArc<Nav>, at: (f64, f64, f64)) -> Result<(f64, f64, f64), String> {
    snap_impl(&nav, to_pos(at))
}

/// Whether the position stands on walkable ground.
#[rustler::nif]
fn valid_position(nav: ResourceArc<Nav>, at: (f64, f64, f64)) -> bool {
    match nav.query() {
        Ok(query) => nearest_poly(&query, &to_pos(at)).is_some(),
        Err(_) => false,
    }
}

/// A random walkable point within `radius` of `center`, or an error when
/// nothing walkable sits inside the circle (or under the center itself).
#[rustler::nif]
fn random_point_around(
    nav: ResourceArc<Nav>,
    center: (f64, f64, f64),
    radius: f64,
) -> Result<(f64, f64, f64), String> {
    let query = nav.query()?;

    let (start_ref, _) =
        nearest_poly(&query, &to_pos(center)).ok_or("no walkable ground under the center")?;

    let mut out_ref: dtPolyRef = 0;
    let mut out_point = [0f32; 3];
    let center = to_pos(center);
    let status = unsafe {
        ms2_find_random_point_around_circle(
            query.0,
            start_ref,
            center.as_ptr(),
            radius as f32,
            query.1,
            &mut out_ref,
            out_point.as_mut_ptr(),
        )
    };
    if failed(status) || out_ref == 0 {
        return Err("no walkable point inside the radius".into());
    }

    Ok((out_point[0] as f64, out_point[1] as f64, out_point[2] as f64))
}

/// Diagnostics for a loaded mesh: how many tiles landed and how many
/// polygons the first tile carries.
#[rustler::nif]
fn mesh_stats(nav: ResourceArc<Nav>) -> (i32, i32) {
    unsafe { (ms2_navmesh_tile_count(nav.0), ms2_navmesh_poly_count(nav.0)) }
}

fn find_path_impl(
    nav: &Nav,
    from: [f32; 3],
    to: [f32; 3],
) -> Result<Vec<(f64, f64, f64)>, String> {
    let query = nav.query()?;

    let (start_ref, _) =
        nearest_poly(&query, &from).ok_or("no walkable ground under the start")?;
    let (end_ref, _) = nearest_poly(&query, &to).ok_or("no walkable ground under the goal")?;

    let mut corridor: Vec<dtPolyRef> = vec![0; MAX_PATH];
    let mut corridor_len = 0i32;
    let status = unsafe {
        ms2_find_path(
            query.0,
            start_ref,
            end_ref,
            from.as_ptr(),
            to.as_ptr(),
            query.1,
            corridor.as_mut_ptr(),
            &mut corridor_len,
            MAX_PATH as i32,
        )
    };
    if failed(status) {
        return Err(format!("corridor search failed (status {status:#x})"));
    }
    corridor_len = corridor_len.clamp(0, MAX_PATH as i32);
    corridor.truncate(corridor_len as usize);
    if corridor.is_empty() {
        return Err("no corridor connects the endpoints".into());
    }

    // a partial corridor never reached the goal poly (stacked floors, mesh
    // gaps): walking it would draw a straight line through the air
    if *corridor.last().unwrap() != end_ref {
        return Err("no corridor connects the endpoints".into());
    }

    let mut points = vec![0f32; MAX_PATH * 3];
    let mut flags = vec![0u8; MAX_PATH];
    let mut refs = vec![0u64; MAX_PATH];
    let mut point_count = 0i32;
    let status = unsafe {
        ms2_find_straight_path(
            query.0,
            from.as_ptr(),
            to.as_ptr(),
            corridor.as_ptr(),
            corridor_len,
            points.as_mut_ptr(),
            flags.as_mut_ptr(),
            refs.as_mut_ptr(),
            &mut point_count,
            MAX_PATH as i32,
        )
    };
    if failed(status) {
        return Err(format!(
            "string pulling failed (status {status:#x}, corridor {corridor_len} polys, first ref {:x})",
            corridor[0]
        ));
    }
    point_count = point_count.clamp(0, MAX_PATH as i32);

    Ok((0..point_count as usize)
        .map(|i| {
            (
                points[i * 3] as f64,
                points[i * 3 + 1] as f64,
                points[i * 3 + 2] as f64,
            )
        })
        .collect())
}

fn snap_impl(nav: &Nav, at: [f32; 3]) -> Result<(f64, f64, f64), String> {
    let query = nav.query()?;
    let (_, point) = nearest_poly(&query, &at).ok_or("no walkable ground within the query box")?;
    Ok((point[0] as f64, point[1] as f64, point[2] as f64))
}

fn nearest_poly(query: &Query, at: &[f32; 3]) -> Option<(dtPolyRef, [f32; 3])> {
    let mut reference: dtPolyRef = 0;
    let mut point = [0f32; 3];
    let status = unsafe {
        ms2_find_nearest_poly(query.0, at.as_ptr(), QUERY_EXTENTS.as_ptr(), query.1, &mut reference, point.as_mut_ptr())
    };
    if failed(status) || reference == 0 {
        return None;
    }
    Some((reference, point))
}

fn to_pos((x, y, z): (f64, f64, f64)) -> [f32; 3] {
    [x as f32, y as f32, z as f32]
}

// -- mesh-set binary parsing ---------------------------------------------------
//
// layout (all little-endian):
//   u32 magic "MSET" | u32 version (1 = C-compatible) | i32 tile count
//   params: f32 origin.x/y/z, f32 tile width, f32 tile height,
//           i32 max tiles, i32 max polys
//   per tile: i64 tile ref, i32 data size, i32 zero padding, then the tile
//   blob — the C-layout mesh data the library consumes as-is

fn parse_mesh_set(bytes: &[u8]) -> Result<(NavMeshParams, Vec<Vec<u8>>), String> {
    let mut reader = Cursor::new(bytes);

    let magic = reader
        .read_u32::<LittleEndian>()
        .map_err(|_| "truncated mesh-set header".to_string())?;
    if magic != MSET_MAGIC {
        return Err(format!("not a mesh-set binary (magic {magic:#x})"));
    }

    let version = reader
        .read_u32::<LittleEndian>()
        .map_err(|_| "truncated mesh-set header".to_string())?;
    if version != MSET_C_COMPAT_VERSION {
        return Err(format!("unsupported mesh-set version {version}"));
    }

    let tile_count = reader
        .read_i32::<LittleEndian>()
        .map_err(|_| "truncated tile count".to_string())?;

    let params = NavMeshParams {
        origin: [
            read_f32(&mut reader)?,
            read_f32(&mut reader)?,
            read_f32(&mut reader)?,
        ],
        tile_width: read_f32(&mut reader)?,
        tile_height: read_f32(&mut reader)?,
        max_tiles: reader
            .read_i32::<LittleEndian>()
            .map_err(|_| "truncated mesh params".to_string())?,
        max_polys: reader
            .read_i32::<LittleEndian>()
            .map_err(|_| "truncated mesh params".to_string())?,
    };

    let mut tiles = Vec::with_capacity(tile_count.max(0) as usize);
    for _ in 0..tile_count.max(0) {
        let _tile_ref = reader
            .read_i64::<LittleEndian>()
            .map_err(|_| "truncated tile header".to_string())?;
        let data_size = reader
            .read_i32::<LittleEndian>()
            .map_err(|_| "truncated tile header".to_string())? as usize;
        // the C-compatible format pads the tile header to the struct layout
        let _padding = reader
            .read_i32::<LittleEndian>()
            .map_err(|_| "truncated tile header".to_string())?;

        let mut blob = vec![0u8; data_size];
        reader
            .read_exact(&mut blob)
            .map_err(|_| "truncated tile data".to_string())?;
        tiles.push(blob);
    }

    Ok((params, tiles))
}

fn read_f32(reader: &mut Cursor<&[u8]>) -> Result<f32, String> {
    reader
        .read_f32::<LittleEndian>()
        .map_err(|_| "truncated mesh params".to_string())
}

fn on_load(env: rustler::Env, _info: rustler::Term) -> bool {
    env.register::<Nav>().is_ok()
}

rustler::init!("Elixir.Ms2ex.Navigation.Native", load = on_load);
