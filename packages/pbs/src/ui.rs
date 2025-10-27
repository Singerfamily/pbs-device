// use color_eyre::Result;
// use crossterm::event::{self, Event};
// use ratatui::{DefaultTerminal, Frame};
//
// pub fn run(mut terminal: DefaultTerminal) -> Result<()> {
//     loop {
//         terminal.draw(render)?;
//         if matches!(event::read()?, Event::Key(_)) {
//             break Ok(());
//         }
//     }
// }
//
// pub fn render(frame: &mut Frame) {
//     frame.render_widget("hello world", frame.area());
// }