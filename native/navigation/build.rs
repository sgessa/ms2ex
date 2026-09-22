use std::path::PathBuf;

fn main() {
    let root = PathBuf::from(std::env::var("CARGO_MANIFEST_DIR").unwrap());

    let detour = root.join("csrc/recastnavigation");
    let mut build = cc::Build::new();
    build
        .cpp(true)
        .std("c++14")
        .include(detour.join("Include"))
        .file(root.join("csrc/shim.cpp"))
        .define("DT_POLYREF64", None)
        .warnings(false)
        .flag_if_supported("-w");

    for entry in std::fs::read_dir(detour.join("Source")).unwrap() {
        let entry = entry.unwrap();
        if entry.path().extension().and_then(|e| e.to_str()) == Some("cpp") {
            build.file(entry.path());
            println!("cargo:rerun-if-changed={}", entry.path().display());
        }
    }
    println!("cargo:rerun-if-changed={}", root.join("csrc/shim.cpp").display());

    build.compile("detour");
}
