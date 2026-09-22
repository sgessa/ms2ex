// C shim over the C++ Detour API: exposes the handful of entry points the
// runtime needs as plain C functions, so the Rust side stays free of C++
// name mangling and bindgen.

#include "recastnavigation/Include/DetourNavMesh.h"
#include "recastnavigation/Include/DetourNavMeshBuilder.h"
#include "recastnavigation/Include/DetourNavMeshQuery.h"
#include "recastnavigation/Include/DetourStatus.h"

#include <cstring>

extern "C" {

dtNavMesh* ms2_navmesh_create(const dtNavMeshParams* params) {
    dtNavMesh* mesh = dtAllocNavMesh();
    if (mesh == nullptr) return nullptr;
    if (dtStatusFailed(mesh->init(params))) {
        dtFreeNavMesh(mesh);
        return nullptr;
    }
    return mesh;
}

void ms2_navmesh_destroy(dtNavMesh* mesh) {
    dtFreeNavMesh(mesh);
}

// addTile takes ownership of the buffer and frees it with Detour's own
// allocator, so the caller's bytes are copied into a Detour allocation
// first — handing over foreign memory corrupts the heap at tile removal
dtStatus ms2_navmesh_add_tile(dtNavMesh* mesh, const unsigned char* data, int data_size) {
    unsigned char* owned = (unsigned char*)dtAlloc(data_size, dtAllocHint::DT_ALLOC_PERM);
    if (owned == nullptr) return DT_FAILURE | DT_OUT_OF_MEMORY;
    memcpy(owned, data, data_size);
    dtTileRef ref = 0;
    dtStatus status = mesh->addTile(owned, data_size, DT_TILE_FREE_DATA, 0, &ref);
    if (dtStatusFailed(status)) dtFree(owned);
    return status;
}

int ms2_navmesh_tile_count(dtNavMesh* mesh) {
    int count = 0;
    for (int i = 0; i < mesh->getMaxTiles(); ++i) {
        const dtMeshTile* tile = mesh->getTileAt(0, 0, i);
        if (tile && tile->header) ++count;
    }
    return count;
}

int ms2_navmesh_poly_count(dtNavMesh* mesh) {
    const dtMeshTile* tile = mesh->getTileAt(0, 0, 0);
    return tile && tile->header ? tile->header->polyCount : 0;
}

dtNavMeshQuery* ms2_query_create(dtNavMesh* mesh, int max_nodes) {
    dtNavMeshQuery* query = dtAllocNavMeshQuery();
    if (query == nullptr) return nullptr;
    if (dtStatusFailed(query->init(mesh, max_nodes))) {
        dtFreeNavMeshQuery(query);
        return nullptr;
    }
    return query;
}

void ms2_query_destroy(dtNavMeshQuery* query) {
    dtFreeNavMeshQuery(query);
}

dtQueryFilter* ms2_filter_create() {
    return new dtQueryFilter();
}

void ms2_filter_destroy(dtQueryFilter* filter) {
    delete filter;
}

dtStatus ms2_find_nearest_poly(dtNavMeshQuery* query, const float* center, const float* extents,
                               dtQueryFilter* filter, dtPolyRef* out_ref, float* out_point) {
    return query->findNearestPoly(center, extents, filter, out_ref, out_point);
}

dtStatus ms2_find_path(dtNavMeshQuery* query, dtPolyRef start_ref, dtPolyRef end_ref,
                       const float* start_pos, const float* end_pos, dtQueryFilter* filter,
                       dtPolyRef* path, int* path_count, int max_path) {
    return query->findPath(start_ref, end_ref, start_pos, end_pos, filter, path, path_count, max_path);
}

dtStatus ms2_find_straight_path(dtNavMeshQuery* query, const float* start_pos, const float* end_pos,
                                const dtPolyRef* path, int path_count, float* points,
                                unsigned char* flags, dtPolyRef* refs, int* point_count,
                                int max_points) {
    return query->findStraightPath(start_pos, end_pos, path, path_count, points, flags, refs,
                                   point_count, max_points);
}

}
