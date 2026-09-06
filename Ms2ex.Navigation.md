# `Ms2ex.Navigation`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/navigation.ex#L1)

Point queries against a map's Recast navmesh: a position is valid when
the navmesh has walkable ground for it. Navmesh coordinates are meters
with Y up, so map positions transform by a -90 degree rotation about X
and a 1/100 scale.

# `valid_position?`

Poly queries use these half extents (in navmesh meters): 2 across,
4 of height tolerance, 2 across.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
