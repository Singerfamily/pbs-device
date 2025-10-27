use std::env;
use std::path::{Path, PathBuf};

pub fn set_working_dir() {
    #[cfg(not(debug_assertions))]
    fn path() -> PathBuf {
        return env::home_dir().unwrap().join(".pbs");
    }

    #[cfg(debug_assertions)]
    fn path() -> PathBuf {
        return Path::new("./working_dir").to_path_buf();
    }

    let root = path();

    if !root.exists() {
        assert!(std::fs::create_dir_all(&root).is_ok());
        println!("Created directory: {}", root.display());
    }

    assert!(env::set_current_dir(&root).is_ok());
    println!(
        "Successfully changed working directory to {}!",
        root.display()
    );

}
