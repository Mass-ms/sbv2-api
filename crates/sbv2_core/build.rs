use dirs::home_dir;
use std::env;
use std::fs;
use std::io::copy;
use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let out_path = PathBuf::from(&env::var("OUT_DIR").unwrap()).join("all.bin");
    println!("cargo:rerun-if-changed=build.rs");

    // First, check for locally built dictionary from make_dict.sh
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let local_dict_path = manifest_dir.join("src/dic/all.dic");

    if local_dict_path.exists() {
        println!("cargo:warning=Using locally built dictionary from AivisSpeech");
        if !out_path.exists() && fs::hard_link(&local_dict_path, &out_path).is_err() {
            println!("cargo:warning=Failed to create hard link, copying instead.");
            fs::copy(&local_dict_path, &out_path)?;
        }
        return Ok(());
    }

    // Fall back to cached or downloaded dictionary
    let static_dir = home_dir().unwrap().join(".cache/sbv2");
    let static_path = static_dir.join("all.bin");

    if static_path.exists() {
        println!("cargo:info=Dictionary file already exists, skipping download.");
    } else {
        println!("cargo:warning=Downloading dictionary file...");
        let mut response =
            ureq::get("https://huggingface.co/neody/sbv2-api-assets/resolve/main/dic/all.bin")
                .call()?;
        let mut response = response.body_mut().as_reader();
        if !static_dir.exists() {
            fs::create_dir_all(static_dir)?;
        }
        let mut file = fs::File::create(&static_path)?;
        copy(&mut response, &mut file)?;
    }
    if !out_path.exists() && fs::hard_link(&static_path, &out_path).is_err() {
        println!("cargo:warning=Failed to create hard link, copying instead.");
        fs::copy(static_path, out_path)?;
    }
    Ok(())
}
