mod atoms {
    rustler::atoms! {
        ok
    }
}

#[rustler::nif]
fn hello() -> rustler::Atom {
    atoms::ok()
}

rustler::init!("Elixir.Fitzyo.GraphAlgorithms");
