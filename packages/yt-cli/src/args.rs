use clap::{
    Parser,
    Subcommand
};

#[derive(Debug, Parser)]
#[clap(author, version, about)]
pub struct CliArgs {
    #[clap(subcommand)]
    pub command: Subcommands,

    #[clap(long, short, action)]
    pub verbose: bool,
}

#[derive(clap::ValueEnum, Clone, Default, Debug, strum_macros::Display)]
pub enum Visibility {
    #[default]
    Unlisted,
    Public,
    Private,
}

#[derive(Debug, Subcommand)]
pub enum Subcommands {
    /// Authenticate with YouTube
    Auth {
        /// Force re-authentication
        #[clap(long, short, action)]
        force: bool,
    },
    /// Start a stream
    Start {
        /// The name of the stream
        #[clap(long, short, env = "PBS_TITLE", default_value = "Sacrament Meeting")]
        title: Option<String>,

        #[clap(long, short, env = "PBS_START_VISIBILITY", default_value = "public")]
        visibility: Option<Visibility>,

        // The stream key to use (if not provided, a new stream will be created)
        // #[clap(long, short, env)]
        // stream_key: Option<String>,
    },
    /// Stop a stream
    Stop {
        /// Delete the stream after stopping
        #[clap(long, short, action, env = "PBS_STOP_DELETE")]
        delete: bool,

        /// The visibility of the stream after stopping
        #[clap(short, long, env = "PBS_STOP_VISIBILITY", default_value = "unlisted")]
        visibility: Option<Visibility>
    },
}

