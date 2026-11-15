import "./register.css";

// vista del formulario de registro (sin backend todavía)
export const SignupCardCombined = () => {
    const manejarEnvio = (evento) => {
        evento.preventDefault();
        const datos = Object.fromEntries(new FormData(evento.currentTarget));
        console.log("Form data:", datos);
    };

    return (
        <section className="registro">
            <div className="registro-tarjeta">
                <div className="registro-encabezado">
                    <span className="registro-logo" aria-hidden="true">
                        Z
                    </span>
                    <div className="registro-titulos">
                        <h1>Start your free trial</h1>
                        <p>Sign up in less than 2 minutes.</p>
                    </div>
                </div>

                <form className="registro-formulario" onSubmit={manejarEnvio}>
                    <div className="registro-campos">
                        <input
                            className="registro-input"
                            name="name"
                            placeholder="Enter your name"
                            aria-label="Name"
                            required
                        />
                        <input
                            className="registro-input"
                            type="email"
                            name="email"
                            placeholder="Enter your email"
                            aria-label="Email"
                            required
                        />
                        <div className="registro-grupo">
                            <input
                                className="registro-input"
                                type="password"
                                name="password"
                                placeholder="Create a password"
                                aria-label="Password"
                                minLength={8}
                                required
                            />
                            <p className="registro-ayuda">Must be at least 8 characters.</p>
                        </div>
                    </div>

                    <div className="registro-acciones">
                        <button className="registro-boton" type="submit">
                            Get started
                        </button>
                        <button className="registro-boton registro-boton--social" type="button">
                            <span className="registro-google" aria-hidden="true">
                                G
                            </span>
                            Sign up with Google
                        </button>
                    </div>
                </form>

                <div className="registro-pie">
                    <span>Already have an account?</span>
                    <a href="#">Log in</a>
                </div>
            </div>
        </section>
    );
};
