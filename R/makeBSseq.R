#' Make an in-memory bsseq object from a biscuit BED
#'
#' Beware that any reasonably large BED files may not fit into memory!
#'
#' @param tbl       A tibble (from read_tsv) or a data.table (from fread)
#' @param params    Parameters from checkBiscuitBED
#' @param simplify  Simplify sample names by dropping .foo.bar.hg19? (or
#'                    similar) (DEFAULT: FALSE)
#' @param verbose   Print extra statements? (DEFAULT: FALSE)
#'
#' @return          An in-memory bsseq object
#'
#' @import GenomicRanges
#' @import bsseq
#' @importFrom methods is as
#'
#' @examples
#'
#'   library(data.table)
#'   library(R.utils)
#'
#'   orig_bed <- system.file("extdata", "MCF7_Cunha_chr11p15.bed.gz",
#'                           package="biscuiteer")
#'   orig_vcf <- system.file("extdata", "MCF7_Cunha_header_only.vcf.gz",
#'                           package="biscuiteer")
#'   params <- checkBiscuitBED(BEDfile = orig_bed, VCFfile = orig_vcf,
#'                             merged = FALSE, how = "data.table")
#'
#'   select <- grep("\\.context", params$colNames, invert=TRUE)
#'   tbl <- fread(gunzip(params$tbx$path, remove = FALSE), sep="\t", sep2=",",
#'                fill=TRUE, na.strings=".", select=select)
#'   unzippedName <- sub("\\.gz$", "", params$tbx$path)
#'   if (file.exists(unzippedName)) {
#'     file.remove(unzippedName)
#'   }
#'   if (params$hasHeader == FALSE) names(tbl) <- params$colNames[select]
#'   names(tbl) <- sub("^#", "", names(tbl))
#'   
#'   tbl <- tbl[rowSums(is.na(tbl)) == 0, ]
#'   bsseq <- makeBSseq(tbl = tbl, params = params)
#'
#' @export
#'
makeBSseq <- function(tbl,
                      params,
                      simplify = FALSE,
                      verbose = FALSE) {

  gr <- resize(makeGRangesFromDataFrame(tbl[, c("chr","start","end")]), 1) 

  # helper fn  
  matMe <- function(x, gr, verbose = FALSE) {
    if (!is(x, "matrix")) {
      if (verbose) message("Turning a vector into a matrix...")
      x <- as.matrix(x)
    }
    return(x)
  }

  # helper fn  
  fixNames <- function(x, gr, what=c("M","Cov"), verbose=FALSE) {
    if (is.null(rownames(x))) {
      if (verbose) message("Adding rownames...")
      rownames(x) <- as.character(gr)
    }
    colnames(x) <- base::sub("beta", match.arg(what), colnames(x))
    return(x)
  }

  # deal with data.table weirdness 
  if (params$how == "data.table") { 
    M <- matMe(fixNAs(
                 round(tbl[,params$betaCols, with=FALSE]*tbl[,params$covgCols,
                       with=FALSE]),
                       y=0,params$sparse), gr)
    Cov <- matMe(fixNAs(tbl[, params$covgCols,with=FALSE], y=0, params$sparse),
                 gr)
  } else { 
    M <- matMe(x=fixNAs(round(tbl[,params$betaCols]*tbl[,params$covgCols]),
                        y=0, params$sparse),
               gr=gr, verbose=verbose)
    Cov <- matMe(x=fixNAs(tbl[, params$covgCols], y=0, params$sparse), 
                 gr=gr, verbose=verbose)
  }
  Cov <- fixNames(Cov, gr, what="Cov", verbose=verbose)
  M <- fixNames(M, gr, what="M", verbose=verbose)
  colnames(Cov) <- colnames(M) <- params$pData$sampleNames
  if (verbose) message("Creating bsseq object...") 
  res <- BSseq(gr=gr, M=M, Cov=Cov, pData=params$pData,
               rmZeroCov=TRUE, sampleNames=params$pData$sampleNames) 
  if (simplify) res <- simplifySampleNames(res)
  return(res)

}
