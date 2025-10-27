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

// impl Visibility {
//     fn as_str(&self) -> &'static str {
//         match self {
//             Visibility::Unlisted => "unlisted",
//             Visibility::Public => "public",
//             Visibility::Private => "private",
//         }
//     }
// }

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
        #[clap(long, short, env)]
        title: Option<String>,

        #[clap(long, short, env)]
        visibility: Option<Visibility>,

        // The stream key to use (if not provided, a new stream will be created)
        // #[clap(long, short, env)]
        // stream_key: Option<String>,
    },
    /// Stop a stream
    Stop {
        /// Delete the stream after stopping
        #[clap(long, short, action, env)]
        delete: bool,

        /// The visibility of the stream after stopping
        #[clap(short, long, env)]
        visibility: Option<Visibility>
    },
}

