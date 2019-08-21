#' @details
#' standardizes (harmonizes) organizational names mainly using procedures described in Thoma et al. (2010) and Magerman, Looy, Bart, & Song (2006) but not only.
#' This is work in progress. Please, file an issues or suggestion if you have any.
#' The main function is [harmonize()]. 
#' @keywords internal
"_PACKAGE"

##' Converts factor to character
##' @param x a vector
##' @param check.numeric check if vector is numeric. Default is TRUE. Takes longer with this check but avoids type conversion (numeric to character).
##' @return character vector
harmonize.defactor.vector <- function(x, check.numeric = TRUE) {
  if(is.factor(x) & check.numeric) {
    levs <- levels(x)
    ## check if levels are numeric (longer)
    ## https://stackoverflow.com/questions/3418128
    if(suppressWarnings(identical(levs
                                , as.character(as.numeric(levs)))))
      as.numeric(levs)[x]
    else
      levs[x]
  }
  else if(is.factor(x))
    levels(x)[x]
  else x
}

## Test
## factor(sample(c("a", "b", "b"), 20, replace = TRUE)) %>% harmonize.defactor.vector

##' Defactor the object
##' 
##' Returns object of the same type without factors
##'
##' @param x an object
##' @inheritDotParams harmonize.defactor.vector
##' @return object of the same type without factors
##'  
##' @import tibble data.table
##' 
##' @export
harmonize.defactor <- function(x, ...) {
  if(is.atomic(x))
    harmonize.defactor.vector(x, ...)
  else if(is.matrix(x))
    as.matrix(lapply(x, harmonize.defactor.vector, ...))
  else if(is.data.table(x))
    as.data.table(lapply(x, harmonize.defactor.vector, ...))
  else if(is_tibble(x))
    as_tibble(lapply(x, harmonize.defactor.vector, ...))
  else if(is.data.frame(x))
    as.data.frame(lapply(x, harmonize.defactor.vector, ...)
                , stringsAsFactors = FALSE)
  else if(is.list(x)) 
    lapply(x, harmonize.defactor.vector, ...)
  else x
}

## Tests
## data.frame(num = factor(sample(runif(5), 20, replace = TRUE))
##          , let = factor(sample(c("a", "b", "b"), 20, replace = TRUE))) %>%
##   harmonize.defactor %>%
##   extract2("num")

##' Adds a suffix to the string and counter at the end if needed
##'
##' @param name Variable name
##' @param suffix Suffix
##' @param x.names Vector of variable names in x to check for duplicates and if we need to add a counter at the end
##' @import magrittr stringr
##' 
##' @return Returns a new name
harmonize.add.suffix <- function(name, suffix, x.names) {
  name.with.suffix <- paste0(name, ".", suffix)
  name.with.suffix.regex <-
    paste0("(?<=", harmonize.escape.regex(name.with.suffix), "\\.)", "\\d+$")
  suffix.nbr.init <- if(name.with.suffix %in% x.names) 0 else NULL
  suffix.nbr <-
    str_extract(x.names, name.with.suffix.regex) %>%
    as.numeric %>%
    {if(all(is.na(.))) suffix.nbr.init
     else max(., na.rm = TRUE)} %>%
    add(1)
  ## return name
  if(length(suffix.nbr) == 0)
    name.with.suffix
  else
    name.with.suffix %>%
    paste0(".", suffix.nbr)
}


## testing
## harmonize.add.suffix("x", "pro"
##                    ## , c("x", "x.pro.20", "foo" , "x.pro.0", "x.pro.3", "var")
##                    ## , c("x", "foo" , "x.pro", "var")
##                    , c("x", "foo" , "x", "var")
##                      )

##' Gets vector, (harmonize it) and put it back.
##'
##' The function `harmonize.x` basically works as two functions depending whether the second optional parameter `x.inset` is provided. If `x.inset` is not provided the function returns a vector (x.vector) that we want to process (harmonize) from object `x` and inset it back to the original object.  If `x.inset` (harmonized x.vector) is provided the function returns updated `x` object with x.vector inserted/updated in it.
##' 
##' @param x an object
##' @param x.inset a vector to inset. Optional. Default is NULL
##' @param x.col vector of interest in `x` object
##' @param x.rows Logical vector to filter records to harmonize. Default is NULL which means do not filter records
##' @param x.rows.col Column that indicates which records to harmonize. If it is set then `x.rows` is ignored
##' @param x.vector.name If `x` is vector use this name for original column if it is in results. Default is "x". If `x` is table the name of `x.col` will be used.
##' @param x.harmonized.col Column in `x` where we want to put/update the `x.inset` vector. Default is NULL which means that we just put `x.inset` as a first vector/column and remove `x.col`. If set and `x.col` and `x.harmonized.col` are the same `x.col` wont be removed.
##' @param x.harmonized.col.update Update values in this column if `x.rows` or `x.rows.col` is set. If set `harmonized.omitted.val` is ignored.
##' @param harmonized.omitted.val If x.rows or x.rows.col is set. Use this value to fill the rest. Default is NA
##' @param harmonized.append If set then put `x.inset` as the last instead of first vector/column. Default is FALSE.
##' @param harmonized.name Use this name for the first column in results (harmonized names). Default is NULL, which means that either x.vector.name if x is vector or original x.col name will be used with `harmonized.suffix` at the end.
##' @param harmonized.suffix If `harmonized.name` is not set the use this as suffix (default is "harmonized"). If the name with the same suffix already exists in `return.x.cols` it will add counter at the end to avoid variables with the same names.
##' @param return.x.cols If x is table, set the columns to cbind to the result table. Default is -1, meaning cbind all but the first (original/unharmonized) column.
##' @param return.x.cols.all Whether to bind all columns in x. Default is FALSE. If set the return.x.cols is ignored
##'
##'
##' @return Vector or data.table
##'
##' @md
##' @import magrittr stringr data.table
##' @export
harmonize.x <- function(x
                      , x.inset = NULL
                      , x.col = 1
                      , x.rows = NULL
                      , x.rows.col = NULL
                      , x.vector.name = "x"
                      , x.harmonized.col = NULL
                      , x.harmonized.col.update = TRUE
                      , harmonized.omitted.val = NA
                      , harmonized.append = FALSE
                      , harmonized.name = NA
                      , harmonized.suffix = "harmonized"
                      , return.x.cols =
                          -ifelse(is.numeric(x.col), x.col, match(x.col, names(x)))
                      , return.x.cols.all = FALSE) {
  x.is.atomic <- is.atomic(x)
  x.length <- if(x.is.atomic) length(x) else nrow(x)
  ## check x.col
  if(length(x.col) != 1)
    stop("x.col should be of length 1")
  if(!is.numeric(x.col) & !is.character(x.col))
    stop("x.col should be ethier numeric or character")
  ## check x.rows.col
  if(!is.null(x.rows.col)) {
    ## check if x[[x.rows.col]] is logical
    if(all(is.logical(x[[x.rows.col]]), na.rm = TRUE)) {
      x.rows <- x[[x.rows.col]]
    } else {
      stop("x[[x.rows.col]] should be logical type column!")
    }
  }
  ## check x.rows
  if(!is.null(x.rows)) {
    ## check if x.rows is logical
    if(is.logical(x.rows)) {
      ## check if x.rows has different length as x
      if(is.logical(x.rows) & length(x.rows) != x.length)
        stop("x.rows has different length as x (length/nrow)!")
      ## check whether all x.rows are FALSE
    } else stop("x.rows should be logical type!")
  }
  ## if nothing was provides as x.vector then make and return one
  if(is.null(x.inset)) {
    ## ------------------------------
    ## get vector to harmonize
    x %>%
      {if(x.is.atomic) . else .[[x.col]]} %>% 
      {if(is.null(x.rows)) . else .[x.rows]} %>%
      harmonize.defactor %>% return()
    ## ------------------------------
  } else {  # if x.inset is provided
    ## ------------------------------
    x.width <- if(x.is.atomic) 1 else ncol(x)
    x.names <- if(x.is.atomic) x.vector.name else names(x)
    ## check x.harmonized.col
    if(!is.null(x.harmonized.col))
      if(length(x.harmonized.col) != 1)
        stop("x.harmonized.col is wrong type, should be length 1")
      else if(x.is.atomic & x.harmonized.col != 1)
        stop("x is vector so the x.harmonized.col could only be 1")
      else if(is.numeric(x.harmonized.col) & x.harmonized.col > x.width)
        stop("Do not have x.harmonized.col in x. Check ncol(x).")
      else if(!is.numeric(x.harmonized.col) & !(x.harmonized.col %in% x.names))
        stop("Do not have x.harmonized.col in x. Check names(x).")
      else ## convert x.harmonized.col to numeric
        x.harmonized.col %<>% ifelse(is.numeric(.), ., match(., names(x)))
    ## harmonize.defactor and convert to data.table
    x %<>% {if(x.is.atomic) harmonize.defactor(.)
            else harmonize.defactor(as.data.table(.))}
    ## TODO: check return.x.cols...
    ## set return.x.cols
    if(length(return.x.cols) == 0) return.x.cols <- 0
    ## set harmonized name
    x.vector.name %<>%
      {if(x.is.atomic) .
       else names(x[,..x.col]) %>%
              ## remove suffix from name if it is already there..
              str_remove(paste0("\\.", harmonized.suffix, "(\\.\\d+$|$)"))}
    harmonized.name %<>%
      {if(is.na(.)) {
         if(return.x.cols.all)
           harmonize.add.suffix(x.vector.name
                              , harmonized.suffix
                              , x.names)
         else
           harmonize.add.suffix(x.vector.name
                              , harmonized.suffix
                              , x.names[return.x.cols])
       } else .}
    ## inset filtered rows
    x.inset %>% 
      {if(!is.null(x.rows))
         if(!is.null(x.harmonized.col))
           if(x.is.atomic)
             inset(x, x.rows, .)
           else
             inset(x[[x.harmonized.col]], x.rows, .)
         else
           inset(rep(harmonized.omitted.val, x.length), x.rows, .)
       else .} %>% 
      ## bind to existing table
      {if(return.x.cols.all |
          (x.is.atomic &
           ifelse(length(return.x.cols) == 1
                , return.x.cols == 1
                , FALSE))) {
         if(isTRUE(harmonized.append)) {
           cbind(x, data.table(.)) %>%
             setnames(c(x.names, harmonized.name))
         } else {
           cbind(data.table(.), x) %>%
             setnames(c(harmonized.name, x.names))
         }
       } else if(x.is.atomic) {
         .
       } else if(x.harmonized.col.update & !is.null(x.harmonized.col)) {
         x[[x.harmonized.col]] <- .
         ## do not remove x.col if it is the same as x.harmonized.col
         return.x.cols %<>%
           extract(. != -x.harmonized.col) %>%
           {if(length(.) == 0) 1:ncol(x) else .}
         as.data.table(x[,..return.x.cols])
       } else {
         if(isTRUE(harmonized.append)) {
           cbind(x[,..return.x.cols], data.table(.)) %>% 
             setnames(c(x.names[return.x.cols], harmonized.name))
         } else {
           cbind(data.table(.), x[,..return.x.cols]) %>% 
             setnames(c(harmonized.name, x.names[return.x.cols]))
         }
       }
      } %>% return()
    ## ------------------------------
  }
}



## undebug(harmonize.x)

## tests
## ------------------------------
## data.table(x.pro.30 = c(1,2,3,4)
##          , y = c(7,8,9,0)
##          , x.pro.5 = 0) %>%
##   harmonize.x(c(5,5,5)
##             , x.rows = c(T,T,F,T)
##             , harmonized.suffix = "pro")

## data.frame(c(1,2,3,4)
##          , c("7","8","9","a")) %>%
##   harmonize.x(x.col = 2
##             , x.rows = c(T,T,F,T))


## data.table(c(1,2,3,4)
##          , c(7,8,9,0)) %>%
##   harmonize.x(x.inset = c(5,5,5)
##             , x.rows = c(T,T,F,T)
##             , harmonized.append = TRUE)

## data.frame(num = c(1,2,3,4)
##          , str = c("7","8","9","a")
##          , x.rows = c(T,T,F,T)) %>%
##   harmonize.x(x.inset = c(5,5,5)
##             , x.col = "num"
##             , x.rows.col = "x.rows"
##             , x.harmonized.col = 1
##             , return.x.cols = -c(1, 3)
##             , x.harmonized.col.update = TRUE)

##' Gets lengths of the object
##' 
##' @param x object (table)
##' @return Width (nrow) of the object. If it is atomic it returns its length.
##' @export
 harmonize.x.length <- function(x) { #
   if(is.atomic(x)) length(x) else nrow(x)
}


##' Gets width of the object
##' 
##' @param x object (table)
##' @return Width (ncol) of the object. If it is atomic it is 1.
##' @export
 harmonize.x.width <- function(x) {
   if(is.atomic(x)) 1 else ncol(x)
}

##' Splits the object (table) in chunks by rows
##'
##' Convenient to apply some function to the table in chunks, e.g., if you want to add display of progress.
##'
##' @param x object or table
##' @param by number of rows to split by
##' @param len length of the table (nrow)
##' 
##' @return List of (sub)tables
##'
##' @export
 harmonize.x.split <- function(x, by, len) {
   split(x, rep(seq(1, len %/% by +1)
              , each = by
              , length.out = len))
 }

## data.table(name = c("MÄKARÖNI ETÖ FKÜSNÖ Ltd"
 ##                   , "MSLab CÖ. <a href=lsdldf> <br> <\\a>"
 ##                   , "MSLab Co."
 ##                   , "MSLaeb Comp."
 ##                   , "MSLab Comp."
 ##                   , "ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝŸ") %>%
 ##              rep(50)
 ##          , foo = "lalala" ) %>% 
 ##   harmonize.x.split(10, nrow(.)) %>%
 ##   sapply(class)

 ## c("MÄKARÖNI ETÖ FKÜSNÖ Ltd"
 ## , "MSLab CÖ. <a href=lsdldf> <br> <\\a>"
 ## , "MSLab Co."
 ## , "MSLaeb Comp."
 ## , "MSLab Comp."
 ## , "ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝŸ") %>%
 ##   rep(50) %>% 
 ##   harmonize.x.split(10, length(.))

#' Removes redundant whitespases
#' @param x table or vector
#'
#' @inheritDotParams harmonize.x
#'
#' @return updated table or vector
#' @import magrittr stringr
#' @export
harmonize.squish.spaces <- function(x, ...) {
  harmonize.x(x, ...) %>% # get x.vector
    str_squish %>%
    harmonize.x(x, ., ...) # put x.vector to x
}

##' Uppercases vector of interest in the object (table)
##' 
##' @param x object
##' 
##' @inheritDotParams harmonize.x
##'
##' @import magrittr
##' 
##' @return updated object
##' @export
harmonize.toupper <- function(x, ...) {
  harmonize.x(x, ...) %>% 
    toupper %>% 
    harmonize.x(x, ., ...)
}

## Tests
## data.table(name = c("MÄKARÖNI ETÖ FKÜSNÖ Ltd"
##                   , "MSLab CÖ. <a href=lsdldf> <br> <\\a>"
##                   , "MSLab Co."
##                   , "MSLaeb Comp."
##                   , "MSLab Comp."
##                   , "ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝŸ") %>%
##              rep(10)
##          , foo = "lalala" ) %>% harmonize.toupper

##' Removes brackets and content in brackets
##' @param x object (table)
##' @inheritDotParams harmonize.x
##' @return updated object
##' 
##' @import stringr magrittr
##' @export
harmonize.remove.brackets  <- function(x, ...) {
  harmonize.x(x, ...) %>% 
    str_replace_all("<[^<>]*>|\\([^()]*\\)|\\{[^{}]*\\}|\\[[^\\[\\]]*\\]", "") %>%
    harmonize.x(x, ., ...)
}


## test
## remove.brackets breaks the encoding (so it is better to apply decoding first)
## harmonize.remove.brackets("fa\xE7ile (lalala) lkj (sdfs) AAA [sdf]")

##' Removes double quotes (deprecated)
##' 
##' (This is a separate procedure because read.csv can not get this substitution in old version of harmonizer)
##'
##' @param x an object
##' @inheritDotParams harmonize.x
##' @return updated object
##' 
##' @import stringr magrittr
harmonize.remove.quotes <- function(x, ...) {
  harmonize.x(x, ...) %>% 
    stri_replace_all_fixed("\"", "") %>% 
    harmonize.x(x, ., ...)
}

##' Escapes special for regex characters
##' @param string character vector 
##' @return character vector with all special to regex characters escaped
##'
##' @import stringr
##' @export
harmonize.escape.regex <- function(string) str_replace_all(string, "(\\W)", "\\\\\\1")


## alternative:
## escape.regex  <- function (string) {
##   gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", string)
## }


##' Escapes special for regex characters conditionally
##' @param strings character vector
##' @param conds character vector of the same length as `strings` with instructions whether to escape regex ("fixed") add beginning ("begins") or ending ("ends") matcher. If value is "regex" then do not change the string
##' @return string with all special to regex characters escaped
##'
##' @import stringr
harmonize.escape.regex.cond <- function(strings, conds) {
  mapply(function(string, cond) {
    if(cond == "fixed") harmonize.escape.regex(string)
    else if(cond == "begins") paste0("^", harmonize.escape.regex(string))
    else if(cond == "ends") paste0(harmonize.escape.regex(string), "$")
    else if(cond == "regex") string
  }
, strings
, conds
, SIMPLIFY = TRUE)
}

## Test escape.regex.cond
## c("MSlab$", "TriloBit.?", "(^0-3)", "Ltd.") %>%
##   escape.regex.cond(c("regex", "fixed", "regex", "ends"))

##' Checks if elements that are either "", NA, NULL or have zero length
##' @param xs vector 
##' @return logical vector of the same length
##' @import magrittr
##' @export
harmonize.is.empty <- function(xs) {
  lapply(xs, function(x) {
    ifelse(length(x) == 0, TRUE, all(x == "" | is.na(x)))
  }) %>%
    unlist(recursive = FALSE)
}

## list("INCORPORATED", NULL, NULL, NULL, NULL) %>% is.empty
## c(NA, "", 3,4, "wsd", NULL) %>% is.empty

##' Removes elements that are either "", NA, NULL or have zero length
##' @param x vector 
##' @return updated vector with empty elements removed
##' @export
harmonize.empty.omit <- function(x) {
  x[!sapply(harmonize.is.empty(x), isTRUE)]
}

## test
## list("INCORPORATED", NULL, NULL, NULL, NULL) %>% empty.omit

##' If column in the `x` table is list unlist it if possible
##' @param x object
##' @return updated object
##' @export
harmonize.unlist.column <- function(x) {
  if(is.atomic(x)) x
  else if(is.list(x)) {
    len <- sapply(x, length)
    if(all(len == 1))
      unlist(x)
    else if(all(len %in% 0:1))
      unlist(inset(x, len == 0, NA))
    else x
  } else x
}


## Tests
## c(1,2,3,4) %>% harmonize.unlist.column
## list(c("a"), NULL, 3, "5", character(0)) %>% harmonize.unlist.column
## list(c("a"), 3, "5") %>% harmonize.unlist.column
## list(c("a", "b", "c"), NULL, 3, "5", character(0)) %>% harmonize.unlist.column

#' Converts HTML characters to UTF-8 (this one is 1/3 faster than htmlParse but it is still very slow)
## from - http://stackoverflow.com/questions/5060076
#' @param x object (table)
#' @param as.single.string If set then collapse characters in the main column of the `x` (i.e., `x.col`) as to a single string. It will increase performance (at least for relatively short tables). Default is FALSE
#' @param as.single.string.sep delimiter for collapsed strings to uncollapse it later. Default is "#_|".
#' @param read.xml If set the it will parse XML. Default is FALSE which means it parses HTML
#' @inheritDotParams harmonize.x
#' @return updated object
#'
#' @import xml2 magrittr
#' @export
harmonize.dehtmlize <- function(x
                              , as.single.string = FALSE
                              , as.single.string.sep = "#_|"
                              , read.xml = FALSE
                              , ...) {
  x.vector <- harmonize.x(x, ...)
  if(as.single.string) {
    x.vector %>%
      paste0(collapse = as.single.string.sep) %>%
      paste0paste0("<x>", ., "</x>") %>% 
      {if(read.xml) read.xml(.)
       else read_html(.)} %>%
      xml_text %>% 
      strsplit(as.single.string.sep, fixed = TRUE)[[1]]
  } else {
    sapply(x.vector, function(str) {
      paste0("<x>", str, "</x>") %>%
        {if(read.xml) read.xml(.)
         else read_html(.)} %>%
        xml_text
    })    
  } %>% 
    harmonize.x(x, ., ...) %>%
    return()
}


## tests
## set.seed(123)
## c("abcd", "&amp; &apos; &gt;", "&amp;", "&euro; &lt;") %>% 
##   sample(100, replace = TRUE) %>% 
##   data.table("lala") %>%
##   harmonize.dehtmlize

#' Detects string encoding
#' @param x object
#' @param codes.append basically `harmonized.append` parameter passed to `harmonize.x` but with new defaults. Default is TRUE.
#' @param codes.suffix basically `harmonized.suffix` parameter passed to `harmonize.x` but with new defaults. Default is "encoding"
#' @param return.codes.only If set it overwrites `return.x.cols` and `x.harmonized.col.update` parameters passed to `harmonize.x`. Default is FALSE.
#' @inheritDotParams harmonize.x -harmonized.suffix -harmonized.append
#' @return updated object
#'
#' @import stringi magrittr
#' @export
harmonize.detect.enc <- function(x
                               , codes.append = TRUE
                               , codes.suffix = "encoding"
                               , return.codes.only = FALSE
                               , ...) {
  dots <- list(...)
  ## set new defaults for harmonize.x
  dots$harmonized.suffix <- codes.suffix
  dots$harmonized.append <- codes.append
  ## set default if it is not set directly return.x.cols
  if(is.null(dots$return.x.cols)) {
    dots$return.x.cols <- 1:harmonize.x.width(x)
  }
  ## setup for return.codes.only
  if(return.codes.only) {
    dots$return.x.cols <- 0
    dots$x.harmonized.col.update <- FALSE
  }
  available.enc.list <- iconvlist()
  x.vector <- do.call(harmonize.x, c(list(x), dots))
  stri_enc_detect(x.vector) %>%
    lapply(function(enc) {
      enc %<>% extract2("Encoding")
      first.ok.enc <- (enc %in% available.enc.list) %>% which %>% extract(1)
      if(length(first.ok.enc) == 0) ""
      else enc[[first.ok.enc]]
    }) %>%
    unlist %>%
    {do.call(harmonize.x, c(list(x), list(.), dots))} %>%
    return()
}


## Test
## c("FAÇILE"
## , "fa\xE7ile"
## , "c\u00b5c\u00b5ber") %>%
##   harmonize.detect.enc(return.codes.only = FALSE)

#' Translates non-ascii symbols to its ascii equivalent
#'
#' It takes characters from this string:
#' ŠŒŽšœžŸ¥µÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝßàáâãäåæçèéêëìíîïðñòóôõöøùúûüýÿ
#' And translates to this one
#' SOZsozYYuAAAAAAACEEEEIIIIDNOOOOOOUUUUYsaaaaaaaceeeeiiiionoooooouuuuyy
#' 
#' @param str String to translate
#' @param detect.encoding Detect encoding of individual elements
#' @inheritDotParams harmonize.x
#' 
#' @import stringi stringr magrittr
#' 
#' @export
harmonize.toascii <- function(x
                            , detect.encoding = FALSE
                            , ...) {
  str <- harmonize.x(x, ...)
  utf <- harmonizer.patterns.ascii$utf %>% paste(collapse = "")
  ascii <- harmonizer.patterns.ascii$ascii %>% paste(collapse = "")
  {if(detect.encoding)  # detect encoding of individual elements
     mapply(function(name, enc)
       iconv(name
           , from = enc
           , to = "UTF-8"
           , sub = "") %>%
       {chartr(utf, ascii, .)}
     , str
     , harmonize.detect.enc(str, return.codes.only = TRUE)
     , SIMPLIFY = FALSE, USE.NAMES = FALSE) %>%
       unlist %>% 
       iconv(to = "ASCII", sub = "")
   else
     enc2utf8(str) %>% 
       {chartr(utf, ascii, .)} %>% 
       iconv(to = "ASCII", sub = "")} %>%
    harmonize.x(x, ., ...)
}


## Test
## harmonize.detect.enc(c("FAÇILE"
##         , "fa\xE7ile"
##         , "c\u00b5c\u00b5ber"))

## c("FAÇILE"
## , "fa\xE7ile"
## , "c\u00b5c\u00b5ber") %>%
##   data.table("coffee") %>% 
## harmonize.toascii(detect.encoding = TRUE)

#' A wrapper for string replacement and cbinding some columns.
#'
#' Optionally matches only at the beginning or at the end of the string.
#' 
#' @param x Vector or table to harmonize.
#' @param patterns Accepts both vector or table. If patterns it is table can also include replacements column.
#' @param patterns.col If patterns is not a vector which column to use. Default is 1.
#' @param patterns.type Kind of pattern. Default is "fixed" (calling code{\link[stringi]{stri_replace_all_fixed}}). Other options are "begins", "ends" - which means that it should only match fixed pattern at the beginning of the string or at the and. Another possible value is "regex" (calling code{\link[stringi]{stri_replace_all_regex}})
#' @param patterns.type.col 
#' @param patterns.replacements.col If patterns is not a vector and includes replacements which column to use for replacements. Default is 2.
#' @param replacements If patterns does not have column with replacements provide it here.
#' @param replacements.col If replacements is not a vector which column to use. Default is 1.
#' @inheritDotParams harmonize.x
#'
#' @return If nothing was indicated to cbind to results then it returns harmonized vector. If something is needs to be cbind then it returns data.table
#' @import stringi stringr magrittr
#' 
#' @export
harmonize.replace <- function(x
                            , patterns
                            , patterns.col = 1
                            , patterns.type = "fixed"
                            , patterns.type.col = NULL
                            , patterns.replacements.col = 2
                            , replacements = NULL
                            , replacements.col = 1
                            , ...) {
  ## check pattern type
  patterns.is.atomic <- is.atomic(patterns)
  patterns.type %<>% {if(length(.) == 1)
                        if(. %in% c("fixed", "begins", "ends", "regex")) .
                        else if(is.numeric(.)) patterns[[.]]
                        else if(!is.null(patterns[[.]])) patterns[[.]]
                        else stop("patterns.type misspecified!")
                      else if(length(.) == ifelse(is.null(nrow(patterns))
                                                , length(patterns)
                                                , nrow(patterns))) .
                      else stop("patterns.type misspecified!")}
  ## get replacesments vectors
  replacements %<>%
    {if (is.null(.)) if (patterns.is.atomic) ""
                     else patterns[[patterns.replacements.col]]
     else if (is.atomic(.)) .
     else .[[replacements.col]]}
  ## get replacesments patterns
  patterns %<>%
    {if (patterns.is.atomic) . else .[[patterns.col]]} %>%
    {if(length(patterns.type) == 1)
       if(patterns.type == "begins") paste0("^", harmonize.escape.regex(.))
       else if(patterns.type == "ends") paste0(harmonize.escape.regex(.), "$")
       else .
     else harmonize.escape.regex.cond(.,patterns.type)}
  ## harmonize
  ## ---------
  x.vector <- harmonize.x(x, ...)
  x.vector %<>% 
    {if(length(patterns.type) == 1 & patterns.type[1] == "fixed") {
       stri_replace_all_fixed(.
                            , patterns
                            , replacements
                            , vectorize_all = FALSE)
     } else {
       stri_replace_all_regex(.
                            , patterns
                            , replacements
                            , vectorize_all = FALSE)
     }}
  ## ---------
  ## inset x.vector
  harmonize.x(x, x.vector, ...) %>% return()
}


## Test harmonize.replace
## data.frame(x.lala = c("lala MSlab"
##                , "this company called TriloBit.? maybe"
##                , "MS007lab, Ltd.")
##          , x.rows = c(TRUE, TRUE, FALSE)
##          , harm = c(1,2,"MSlab")) %>%
##   harmonize.replace(patterns = c("MSlab$", "TriloBit.?", "[0-3]*", "Ltd.")
##                   , patterns.type = c("regex", "fixed", "regex", "ends")
##                   , harmonized.omitted.col = 3
##                   , x.rows = c(TRUE, TRUE, FALSE)
##                   , return.x.cols = 3
##                   )

#' This function is basically meant for coding names based on certain pattern
#'
#' Optionally matches only at the beginning or at the end of the string.
#' 
#' @param x Vector or table to detect in.
#' @param patterns Accepts both vector or table. If patterns it is table can also include replacements column.
#' 
#' @param patterns.col If patterns is not a vector specifies which column to use. Default is 1.
#' @param patterns.type Kind of pattern. Default is "fixed" (calling code{\link[stringi]{stri_replace_all_fixed}}). Other options are "begins", "ends" - which means that it should only match fixed pattern at the beginning of the string or at the and. Another possible value is "regex" (calling code{\link[stringi]{stri_replace_all_regex}})
#' @param patterns.codes.col If patterns is table which column to use as codes column.
#' 
#' @param codes If provided use it as codes. Should be the same length as patterns
#' @param codes.col If codes is not vector use this column for codes
#' @param codes.name If provided use it as a name for codes column in results.
#' @param codes.suffix If codes.name is not provided use this suffix to x.col name or x.vector.name if x is vector
#' @param codes.first If TRUE then return only codes for the first detected pattern. Otherwise return list of all matched codes. Default is FALSE.
#' 
#' @param x.codes.col If x is table, which column to use for making/merging/adding newly detected codes. Default is last column of x or NULL is x is vector
#' @param x.codes.update.empty If set then detect and add new codes only for records (rows) that were not yet coded (i.e., related codes are either "", NA or length == 0).
#' @param x.codes.merge If set then merge (append) new codes to existing one.
#' @param return.codes.only If set then just return codes vector. Default is FALSE. Basically it resets return.x.cols to 0. So if it is set the return.x.cols (of harmonize.x helper) will be ignored.
#' @inheritDotParams harmonize.x
#' 
#' @return If nothing was indicated to cbind to results then it returns harmonized vector. If something is needs to be cbind then it returns data.table
#'
#' @import stringi stringr magrittr
#' 
#' @export
harmonize.detect <- function(x
                           , patterns
                           , patterns.col = 1
                           , patterns.type = "fixed"
                           , patterns.codes.col = 2
                           , codes = NULL
                           , codes.col = 1
                           , codes.first = FALSE
                           , codes.name = NA
                           , codes.suffix = "coded"
                           , codes.omitted.val = NA
                           , codes.append = TRUE
                           , x.col = 1
                           , x.codes.col = NULL
                           , x.codes.update.empty = FALSE
                           , x.codes.merge = FALSE
                           , return.codes.only = FALSE
                           , ...) {
  ## get dots variables
  dots <- list(...)
  ## set new defaults for harmonize.x
  dots$x.harmonized.col <- x.codes.col
  dots$x.harmonized.col.update <- x.codes.update.empty | x.codes.merge
  dots$harmonized.omitted.val <- codes.omitted.val
  dots$harmonized.name <- codes.name
  dots$harmonized.suffix <- codes.suffix
  dots$harmonized.append <- codes.append
  ## setup for return.codes.only
  if(return.codes.only) {
    dots$return.x.cols <- 0
    dots$x.harmonized.col.update <- FALSE
  }
  ## set default if it is not set directly return.x.cols
  if(is.null(dots$return.x.cols)) {
    dots$return.x.cols <- 1:harmonize.x.width(x)
  }
  ## add other defaults
  ## set existing codes vector
  ## TODO: separate check for x.codes.col with messages
  if(isTRUE(length(x.codes.col) == 1 &
            ifelse(is.numeric(x.codes.col)
                 , x.codes.col <= nrow(x)
                 , x.codes.col %in% names(x)))) {
    ## if x.codes.update.empty is set filter those that have codes already
    if(x.codes.update.empty & is.null(dots$x.rows)) {
      dots$x.rows <-
        harmonize.x(x, x.col = x.codes.col) %>%
        harmonize.is.empty
      ## if all dots$x.rows are FALSE so anything add and just return original
      if(all(!dots$x.rows)) return(x)
      x.codes <- NULL
    } else {
      ## get codes vector (filter with x.rows)
      x.codes <- harmonize.x(x
                           , x.col = x.codes.col
                           , x.rows = dots$x.rows)
    }
  } else {
    x.codes <- NULL
  }
  ## get x vector to detect in (with new x.rows)
  x.vector <- do.call(harmonize.x, c(list(x), dots))
  ## set codes column name
  codes.name %<>%
    {if(!is.na(.)) .
     else names(patterns)[patterns.codes.col] %>% 
            {if(!is.null(.)) .
             else names(x)[x.col] %>%
                    {if(!is.null(.)) paste0(., ".", codes.suffix)
                     else paste0(x.vector.name, ".", codes.suffix)}}}
  ## check existing codes
  codes %<>%
    {if(!is.null(.)) .
     else patterns %>%
            {if(is.atomic(.)) .
             else .[[patterns.codes.col]]}} %>%
    harmonize.defactor
  ## set patterns
  patterns %<>%
    {if(is.atomic(.)) .
     else .[[patterns.col]]} %>%
    harmonize.defactor %>% 
    {if(patterns.type == "begins")
       paste0("^", harmonize.escape.regex(.))
     else if(patterns.type == "ends")
       paste0(harmonize.escape.regex(.), "$")
     else .}
  ## do detection
  mapply(
    function(pattern, code) {
      x.vector %>%
        {if(patterns.type == "fixed")
           stri_detect_fixed(., pattern)
         else
          stri_detect_regex(., pattern)} %>% 
        ifelse(code, NA) %>%
        ## remove empty string ("") codes
        ifelse(. == "", NA, .)
    }
  , patterns
  , codes
  , SIMPLIFY = FALSE, USE.NAMES = FALSE) %>%
    ## transpose list of vectors
    {do.call(mapply, c(c, ., SIMPLIFY = FALSE, USE.NAMES = FALSE))} %>% 
    ## remove empty codes
    ## lapply(na.omit) %>%
    lapply(harmonize.empty.omit) %>% 
    ## check if only first detected code is needed
    {if(codes.first) lapply(.,extract, 1) else .} %>%
    ## check if we need to merge
    {if(x.codes.merge & !is.null(x.codes))
       mapply(function(a,b) c(b, a)
            , .
            , x.codes[if(is.null(dots$x.rows)) TRUE else dots$x.rows]
            , SIMPLIFY = FALSE)
     else .} %>%
    ## remove empty codes
    lapply(harmonize.empty.omit) %>%
    harmonize.unlist.column %>% 
  ## inset records
    {do.call(harmonize.x, c(list(x), list(.), dots))}
}




## Tests
## data.frame(
##   name =   c("MSlab Co."
##            , "IBM Corp."
##            , "Tilburg University")
## , codes = c("",3,NA)) %>%
##   harmonize.detect(c("Co.", "Corp.", "MS")
##                  , patterns.type = "ends"
##                  , x.codes.col = 2
##                  , x.codes.merge = TRUE
##                  , return.codes.only = TRUE)

## c("MSlab Co."
## , "IBM Corp."
## , "Tilburg University") %>% 
##   harmonize.detect(data.table(c("Co.", "Co")
##                             , type = c("corp", "corp2")
##                             , some.extra.col = c(1,2)))

## c("MSlab Co."
## , "IBM Corp."
## , "Tilburg University") %>% 
##   harmonize.detect(data.table(c("Co.", "Co")
##                             , type = c(FALSE, TRUE)
##                             , some.extra.col = c(1,2))
##                  , codes.first = TRUE) %>%
##   extract2("x.coded")

## c("MSlab Co."
## , "IBM Corp."
## , "Tilburg University") %>% 
##   harmonize.detect(data.frame(c("Co.", "Co")
##                             , type = c("corp", "corp2"))
##                  , codes.first = TRUE
##                  , patterns.type = "ends")

##' Harmonizes organizational names. Takes either vector or column in the table.
##' 
##' @param x object (table)
##' @param procedures List of procedures (closures) to apply to x. If we need to pass arguments to some of the procedures it can be done by specifying sub-list where the first element is procedure and the rest its arguments.
##' @param progress Show the progress? Default is TRUE
##' @param progress.min The minimum number of rows the x should have for automatic progress estimation. If x has less rows no progress will be shown. Default is 10^5
##' @param progress.by If set it will divide the x into chunk of this amount of rows. Default is NA.
##' @param progress.percent Number of percents that represent one step in progress. Value should be between 0.1 and 50. Default is 1 which means it will try to chunk the x into 100 pieces.
##' @param progress.message.use.names Should we use names from `procedures` list to report progress. Default is TRUE.
##' @param quite Suppress all messages. Default is FALSE.
##' @inheritDotParams harmonize.x
##' 
##' @return
##'
##' @import stringi stringr magrittr
##' @export
harmonize <- function(x
                    , procedures = harmonize.default.procedures
                    , progress = TRUE
                    , progress.min = 10^5
                    , progress.by = NA
                    , progress.percent = 1
                    , progress.message.use.names = TRUE
                    , quite = FALSE
                    , ...) {
  ## make format of the massages for procedures
  message.delimiter <- paste(c("\n", rep("-", 65), "\n"), collapse = "")
  message.init <- paste0("\nApplying harmonization procedures:", message.delimiter)
  message.done  <- "\b\b\b\bDONE"
  progress.format <- "\b\b\b\b%3.0f%%"
  message.format <- "* %-60.60s...."
  message.fin <- paste0(message.delimiter, "Harmonization is done!\n")
  ## check progress.percent
  if(progress.percent < 0.1 | progress.percent > 50)
    stop("Please, set progress.percent between 0.1 and 50")
  ## ensure that x is either vector or data.table
  x %<>% {
    if(is.atomic(.)) .
    else if(is.data.table(.)) .
    else if(is_matrix(.)) as.data.table(.)
    else if(is_tible(.)) as.data.table(.)
    else if(is.data.frame(.)) as.data.table(.)
    else if(is.list(.)) stop("x is list. Please, provide either vector or table")
  }
  ## Set progress.by
  progress.by <- if(!progress | quite) NA
                 else {
                   ## calculate the length of the x
                   x.length <- x %>% {if(is.atomic(.)) length(.) else nrow(.)}
                   if(x.length < progress.min) NA
                   else if(!is.na(progress.by)) {
                     ## if progress.by is set check if it is
                     ## at least twice less than x.length
                     ## and more that 1/1000 of x.length
                     if(progress.by > x.length/1000 &
                        progress.by*2 < x.length) progress.by
                     else NA
                   } else round(x.length/(100/progress.percent))
                 }
  ## Apply Procedures
  if(!quite) message(message.init)
  for(p in 1:length(procedures)) {
    ## get procedure function
    procedure.fun <- procedures[[p]] %>% extract2(1)
    ## get procedure arguments
    procedure.args <- procedures[[p]] %>%
      ## remove progress arg if it is there
      extract(-c(1, which(names(.) == "progress")))
    ## get procedure names
    procedure.name <- names(procedures)[p] %>%
        {if(harmonize.is.empty(.) | !progress.message.use.names)
             procedure.fun
         else .}
    ## Anounce Procedure Name
    if(!quite) packageStartupMessage(sprintf(message.format, procedure.name)
                                   , appendLF = FALSE)
    ## Check if we need report progress:
    ## progress is set & progress = FALSE is absent in the arguments
    if(!is.na(progress.by) &
       !isFALSE(procedures[[p]]["progress"][[TRUE]])) {
      ## check if we need to split..
      if(!isTRUE(class(x) == "list")) {
        x %<>% harmonize.x.split(progress.by, x.length)
      }
      ## set progress counter
      i <- 0; env <- environment()
      ## Apply procedure to list!
      x %<>% lapply(function(x.by) {
        ## apply procedure fun with args
        x.by %<>%
          list %>%
          c(procedure.args) %>%
          do.call(procedure.fun, .)
        ## Increment progress counter
        assign("i", i + 100 * progress.by / x.length, envir = env)
        ## Anounce progress
        packageStartupMessage(sprintf(progress.format, i)
                            , appendLF = FALSE)
        return(x.by)
      })
    } else {
      ## check if we need to rbindlist..
      if(isTRUE(class(x) == "list")) {
        if(is.atomic(x[[1]])) x %<>% unlist(use.names = FALSE)
        else x %<>% rbindlist
      }
      ## Apply procedure fun with args!
      x %<>% 
        list %>%
        c(procedure.args) %>%
        do.call(procedure.fun, .)
    }
    ## Anounce DONE
    if(!quite) packageStartupMessage(message.done)
  }
  if(!quite) message(message.fin)
  ## Return X
  if(isTRUE(class(x) == "list")) {
    if(is.atomic(x[[1]])) x %>% unlist(use.names = FALSE)
    else x %>% rbindlist
  } else x
}


## tests
## dummy <- function(x, n) {
##   for(i in 1:n) x <- sqrt(x)^2
##   return(x)
## }

## list("Squaring stuff" = "sqrt"
##     ,list("abs", progress = FALSE)
##     ,list("log", base = 10)
##    , "My function" = list("dummy", 10^6, progress = TRUE)) %>%
##   harmonize(1:10^2
##           , . 
##           , progress.min = 10
##           , progress.by = 30)
