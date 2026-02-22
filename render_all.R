slides_dir <- "D:/TCU/Lecture/statistics/2026/_Slides"

weeks <- c("W01","W02","W03","W04","W05","W06","W07","W08","W09","W10","W12","W13","W14","W15")

for (w in weeks) {
  rmd <- file.path(slides_dir, paste0(w, "_slides.Rmd"))
  cat("\n=== Rendering", rmd, "===\n")
  tryCatch(
    rmarkdown::render(rmd, quiet = FALSE),
    error = function(e) cat("ERROR in", w, ":", conditionMessage(e), "\n")
  )
}

cat("\n=== Done ===\n")
