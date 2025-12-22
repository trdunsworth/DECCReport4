test_hello_world.R
library(testthat)

test_that("hello world functionality", {
  expect_equal("Hello, World!", "Hello, World!")
})

testthat.R
library(testthat)
test_dir("testthat")