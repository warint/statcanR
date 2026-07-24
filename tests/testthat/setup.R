# Redirect the package cache directory into a temporary location so the test
# suite never reads from or writes to the real user cache (catalogue, catalogue
# tokens, and cube metadata all live there).
cache_home <- tempfile("statcanR-cache-")
dir.create(cache_home, recursive = TRUE, showWarnings = FALSE)
old_cache <- Sys.getenv("R_USER_CACHE_DIR", unset = NA)
Sys.setenv(R_USER_CACHE_DIR = cache_home)

withr::defer(
  {
    if (is.na(old_cache)) {
      Sys.unsetenv("R_USER_CACHE_DIR")
    } else {
      Sys.setenv(R_USER_CACHE_DIR = old_cache)
    }
    unlink(cache_home, recursive = TRUE, force = TRUE)
  },
  teardown_env()
)
