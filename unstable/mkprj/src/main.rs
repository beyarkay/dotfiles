use clap::Parser;
use log::info;
use std::error::Error;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Name of the project
    #[arg(short, long)]
    name: Option<String>,
}

fn main() -> Result<(), Box<dyn Error>> {
    env_logger::init();
    let args: Args = Args::parse();
    info!("{args:?}");
    if let Some(name) = args.name {
        // 1. Create the project directory
        info!("Creating project directory {:?}", name);
        std::fs::create_dir(name)?;
        // 2. Init the git repo
        // 3. Add README.md, .gitignore
        // 4. Commit new files to git
        Ok(())
    } else {
        return Err("You must specify a project name".into());
    }
}

fn create_file(path: &str, _content: String) -> Result<(), Box<dyn Error>> {
    let file_path = std::path::Path::new(path);
    let parent_dir = file_path.parent().unwrap();
    std::fs::create_dir_all(parent_dir)?;
    Ok(())
}
