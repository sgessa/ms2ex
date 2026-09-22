//! Generates the synthetic mesh-set fixtures the Elixir tests run against:
//! small hand-authored tiles (convex quads with internal links, one detail
//! triangle pair per quad, a single-leaf BV tree) wrapped in the `MSET`
//! container the loader parses. Synthetic geometry only — nothing here is
//! derived from client data.

use std::fs;
use std::path::PathBuf;

// dtMeshHeader magic/version
const DNAV_MAGIC: u32 = 0x444E_4156;
const DNAV_VERSION: i32 = 7;
const MSET_MAGIC: u32 = 0x4D53_4554;

#[derive(Clone, Copy, Debug)]
struct V3(f32, f32, f32);

struct Quad {
    // corner indices, in winding order
    verts: [usize; 4],
    // per-edge neighbor: poly index + 1, or 0 for boundary edges
    neis: [u16; 4],
}

struct Tile {
    verts: Vec<V3>,
    quads: Vec<Quad>,
}

fn mesh_set(tile: &Tile) -> Vec<u8> {
    let poly_count = tile.quads.len() as i32;
    let detail_tri_count = poly_count * 2;

    let mut bmin = [f32::MAX; 3];
    let mut bmax = [f32::MIN; 3];
    for V3(x, y, z) in &tile.verts {
        bmin[0] = bmin[0].min(*x);
        bmin[1] = bmin[1].min(*y);
        bmin[2] = bmin[2].min(*z);
        bmax[0] = bmax[0].max(*x);
        bmax[1] = bmax[1].max(*y);
        bmax[2] = bmax[2].max(*z);
    }

    // ---- dtMeshHeader (C layout) ----
    let mut h: Vec<u8> = Vec::new();
    put_i32(&mut h, DNAV_MAGIC as i32);
    put_i32(&mut h, DNAV_VERSION);
    put_i32(&mut h, 0); // x
    put_i32(&mut h, 0); // y
    put_i32(&mut h, 0); // layer
    put_i32(&mut h, 0); // userId
    put_i32(&mut h, poly_count);
    put_i32(&mut h, tile.verts.len() as i32);
    put_i32(&mut h, poly_count * 4); // maxLinkCount
    put_i32(&mut h, poly_count); // detailMeshCount
    put_i32(&mut h, 0); // detailVertCount
    put_i32(&mut h, detail_tri_count);
    put_i32(&mut h, poly_count); // bvNodeCount (one leaf per poly)
    put_i32(&mut h, 0); // offMeshConCount
    put_i32(&mut h, 0); // offMeshBase
    put_f32(&mut h, 1.4); // walkableHeight
    put_f32(&mut h, 0.3); // walkableRadius
    put_f32(&mut h, 0.7); // walkableClimb
    for v in bmin {
        put_f32(&mut h, v);
    }
    for v in bmax {
        put_f32(&mut h, v);
    }
    put_f32(&mut h, 100.0); // bvQuantFactor

    let mut blob = h;

    // ---- verts ----
    for V3(x, y, z) in &tile.verts {
        put_f32(&mut blob, *x);
        put_f32(&mut blob, *y);
        put_f32(&mut blob, *z);
    }

    // ---- polys (dtPoly, 32 bytes each) ----
    for quad in &tile.quads {
        put_i32(&mut blob, 0); // firstLink
        for i in 0..6 {
            let vert = if i < 4 { quad.verts[i] as u16 } else { 0 };
            put_u16(&mut blob, vert);
        }
        for i in 0..6 {
            let nei = if i < 4 { quad.neis[i] } else { 0 };
            put_u16(&mut blob, nei);
        }
        put_u16(&mut blob, 1); // flags (walkable)
        blob.push(4); // vertCount
        blob.push(0); // areaAndtype (ground)
    }

    // ---- links: parseTile carves the link pool out of the blob itself
    // (maxLinkCount entries, all zero; internal links are filled in there) ----
    let max_link_count = poly_count * 4;
    for _ in 0..max_link_count * 16 {
        blob.push(0);
    }

    // ---- detail meshes (dtPolyDetail: u32 vertBase, u32 triBase, u8
    // vertCount, u8 triCount, 2 bytes struct padding): corners only ----
    for i in 0..poly_count {
        put_i32(&mut blob, 0); // vertBase
        put_i32(&mut blob, i * 2); // triBase
        blob.push(0); // vertCount
        blob.push(2); // triCount
        blob.push(0); // padding
        blob.push(0); // padding
    }

    // ---- detail tris: two per quad with POLY-LOCAL corner indices (the
    // fourth byte marks which tri edges are polygon-boundary — the
    // closest-boundary-point walk depends on them; the diagonal is
    // interior) ----
    for _ in &tile.quads {
        blob.extend_from_slice(&[0, 1, 2, 0b011]);
        blob.extend_from_slice(&[0, 2, 3, 0b101]);
    }

    // ---- BV tree: one leaf per polygon (leaf i = poly index), each
    // covering that polygon's bounds ----
    let q = |v: f32, lo: f32| ((v - lo) * 100.0).clamp(0.0, 65535.0) as u16;
    for (index, quad) in tile.quads.iter().enumerate() {
        let mut qmin = [f32::MAX; 3];
        let mut qmax = [f32::MIN; 3];
        for vi in quad.verts {
            let vert = tile.verts[vi];
            qmin[0] = qmin[0].min(vert.0);
            qmin[1] = qmin[1].min(vert.1);
            qmin[2] = qmin[2].min(vert.2);
            qmax[0] = qmax[0].max(vert.0);
            qmax[1] = qmax[1].max(vert.1);
            qmax[2] = qmax[2].max(vert.2);
        }
        for i in 0..3 {
            put_u16(&mut blob, q(qmin[i], bmin[i]));
        }
        for i in 0..3 {
            put_u16(&mut blob, q(qmax[i], bmin[i]));
        }
        put_i32(&mut blob, index as i32); // leaf: first (and only) poly
    }

    // ---- MSET container ----
    let mut out: Vec<u8> = Vec::new();
    put_u32(&mut out, MSET_MAGIC);
    put_u32(&mut out, 1); // C-compatible version
    put_i32(&mut out, 1); // tile count
    put_f32(&mut out, bmin[0]);
    put_f32(&mut out, bmin[1]);
    put_f32(&mut out, bmin[2]);
    put_f32(&mut out, bmax[0] - bmin[0]); // tile width
    put_f32(&mut out, bmax[2] - bmin[2]); // tile height
    put_i32(&mut out, 1); // max tiles
    put_i32(&mut out, poly_count); // max polys
    put_i64(&mut out, 0); // tile ref
    put_i32(&mut out, blob.len() as i32);
    put_i32(&mut out, 0); // C-compatible padding
    out.extend(blob);
    out
}

fn put_i32(out: &mut Vec<u8>, v: i32) {
    out.extend_from_slice(&v.to_le_bytes());
}

fn put_u32(out: &mut Vec<u8>, v: u32) {
    out.extend_from_slice(&v.to_le_bytes());
}

fn put_i64(out: &mut Vec<u8>, v: i64) {
    out.extend_from_slice(&v.to_le_bytes());
}

fn put_u16(out: &mut Vec<u8>, v: u16) {
    out.extend_from_slice(&v.to_le_bytes());
}

fn put_f32(out: &mut Vec<u8>, v: f32) {
    out.extend_from_slice(&v.to_le_bytes());
}

// the flat L: A covers x 0..4 / z 0..4, B x 4..8 / z 0..4, C x 4..8 / z
// 4..8 — clockwise winding like generated meshes
fn l_shape() -> Tile {
    let verts = vec![
        V3(0.0, 0.0, 0.0),
        V3(4.0, 0.0, 0.0),
        V3(4.0, 0.0, 4.0),
        V3(0.0, 0.0, 4.0),
        V3(8.0, 0.0, 0.0),
        V3(8.0, 0.0, 4.0),
        V3(4.0, 0.0, 8.0),
        V3(8.0, 0.0, 8.0),
    ];

    Tile {
        verts,
        quads: vec![
            // A: [0,3,2,1], east edge (2->1) neighbors B
            Quad {
                verts: [0, 3, 2, 1],
                neis: [0, 0, 2, 0],
            },
            // B: [1,2,5,4], west edge (1->2) neighbors A, north (2->5) C
            Quad {
                verts: [1, 2, 5, 4],
                neis: [1, 3, 0, 0],
            },
            // C: [2,6,7,5], south edge (5->2) neighbors B
            Quad {
                verts: [2, 6, 7, 5],
                neis: [0, 0, 0, 2],
            },
        ],
    }
}

// two identical floors stacked 3m apart: no links between them
fn stacked() -> Tile {
    let verts = vec![
        V3(0.0, 0.0, 0.0),
        V3(4.0, 0.0, 0.0),
        V3(4.0, 0.0, 4.0),
        V3(0.0, 0.0, 4.0),
        V3(0.0, 3.0, 0.0),
        V3(4.0, 3.0, 0.0),
        V3(4.0, 3.0, 4.0),
        V3(0.0, 3.0, 4.0),
    ];

    Tile {
        verts,
        quads: vec![
            Quad {
                verts: [0, 3, 2, 1],
                neis: [0, 0, 0, 0],
            },
            Quad {
                verts: [4, 5, 6, 7],
                neis: [0, 0, 0, 0],
            },
        ],
    }
}

// a single open 40x40 floor for chase tests
fn open() -> Tile {
    let verts = vec![
        V3(0.0, 0.0, 0.0),
        V3(40.0, 0.0, 0.0),
        V3(40.0, 0.0, 40.0),
        V3(0.0, 0.0, 40.0),
    ];

    Tile {
        verts,
        quads: vec![Quad {
            verts: [0, 3, 2, 1],
            neis: [0, 0, 0, 0],
        }],
    }
}

// a main island and a detached island with no connection between them
fn islands() -> Tile {
    let verts = vec![
        V3(0.0, 0.0, 0.0),
        V3(40.0, 0.0, 0.0),
        V3(40.0, 0.0, 40.0),
        V3(0.0, 0.0, 40.0),
        V3(60.0, 0.0, 0.0),
        V3(64.0, 0.0, 0.0),
        V3(64.0, 0.0, 40.0),
        V3(60.0, 0.0, 40.0),
    ];

    Tile {
        verts,
        quads: vec![
            Quad {
                verts: [0, 3, 2, 1],
                neis: [0, 0, 0, 0],
            },
            Quad {
                verts: [4, 7, 6, 5],
                neis: [0, 0, 0, 0],
            },
        ],
    }
}

fn main() {
    let out_dir = PathBuf::from(
        std::env::args()
            .nth(1)
            .expect("usage: gen_fixtures <output-dir>"),
    );
    fs::create_dir_all(&out_dir).unwrap();
    fs::write(out_dir.join("l_shape.mset"), mesh_set(&l_shape())).unwrap();
    fs::write(out_dir.join("stacked.mset"), mesh_set(&stacked())).unwrap();
    fs::write(out_dir.join("open.mset"), mesh_set(&open())).unwrap();
    fs::write(out_dir.join("islands.mset"), mesh_set(&islands())).unwrap();
    println!("wrote fixtures to {}", out_dir.display());
}
