# Greeter App for demonstrating {shinytest2}

This app was used in Part 3 of a blog series about shinytest2.
The app was developed using [{leprechaun}](https://leprechaun.opifex.org/#/).

The package needs to be loaded before the app can be run:

```r
devtools::load_all()

# To run the app use the `run` function in the package
run()
```

There is a single test-case in the file `./tests/testthat/test-e2e-greeter_accepts_username.R`.
The expected values for the test-cases are embedded in the test-case definitions, so there is
no `_snaps` directory.

To run the {shinytest2}-based test, use the following:

```r
devtools::load_all()

testthat::test_local()
```

