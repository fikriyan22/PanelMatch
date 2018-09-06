# Functions related to finding treated units, matched sets
#' \code{findAllTreated} is used to identify t,id pairs of units for which a matched set might exist. 
#' More precisely, it finds units for which at time t, the specified treatment has been applied, but at time t - 1, the treatment has not.
#'
#'
#' @param dmat Data frame or matrix containing data used to identify potential treated units. Must be specified in such a way that a combination of time and id variables will correspond to a unique row. Must also contain at least a binary treatment variable column as well. 
#' @param treatedvar Character string that identifies the name of the column in \code{dmat} that provides information about the binary treatment variable
#' @param time.var Character string that identifies the name of the column in \code{dmat} that contains data about the time variable
#' @param unit.var Character string that identifies the name of the column in \code{dmat} that contains data about the variable used as a unit id.
#' @param hasbeensorted variable that only has internal usage for optimization purposes. There should be no need for a user to toggle this
#' 
#' @return \code{findAllTreated} returns a subset of the data in the \code{dmat} data frame, containing only treated units for which a matched set might exist
#'
#' @examples \dontrun{
#' treateds <- findAllTreated(dmat = dem, treatedvar = "dem", time.var = "year", unit.var = "wbcode2")
#' }
#' @export

findAllTreated <- function(dmat, treatedvar, time.var, unit.var, hasbeensorted = FALSE)
{
  dmat <- dmat[, c(unit.var, time.var, treatedvar)]
  #subset the columns to just the data needed for this operation
  
  colidx <- which(colnames(dmat) == treatedvar)
  if(length(colidx) > 1) stop("error in column naming scheme")
  uidx <- which(colnames(dmat) == unit.var)
  if(length(uidx) > 1) stop("error in column naming scheme")
  
  if(hasbeensorted)
  {
    odf <- dmat
  }
  else
  {
    odf <- dmat[order(dmat[,unit.var], dmat[,time.var]), ]  
  }
  
  # Verifying that time and unit data are integers -- perhaps later shift this to an automatic conversion process?
  if( any(head(odf[, unit.var]) %% 1 != 0) ) stop("unit data are not integer") # just doing the first few to check for efficiency purposes. 
  if( any(head(odf[, time.var]) %% 1 != 0) ) stop("time data are not integer") 
  
  t.history <- odf[,treatedvar]
  t.idxs <- which(t.history == 1)
  
  num.df <- as.matrix(odf)
  if(!is.numeric(num.df)) stop("data in treated, time, or id columns is not numeric")
  
  ind <- get_treated_indices(num.df, t.idxs - 1, colidx - 1, uidx - 1)
  treated.unit.indices <- t.idxs[ind]
  
  return(odf[treated.unit.indices, ])
}


#' \code{get.matchedsets} is used to identify matched sets for a given unit with a specified i, t.
#' @param t integer vector specifying the times of treated units for which matched sets should be found. This vector should be the same length as the following \code{id} parameter -- the entries at corresponding indices in each vector should form the t,id pair of a specified treatment unit. 
#' @param id integer vector specifying the unit ids of treated units for which matched sets should be found. note that both \code{t} and \code{id} can be of length 1
#' @param L An integer value indicating the length of treatment history to be matched
#' @param data data frame containing the data to be used for finding matched sets.
#' @param t.column Character string that identifies the name of the column in \code{data} that contains data about the time variable. Each specified entry in \code{t} should be somewhere in this column in the data
#' @param id.column Character string that identifies the name of the column in \code{data} that contains data about the unit id variable. Each specified entry in \code{id} should be somewhere in this column in the data
#' @param treatedvar Character string that identifies the name of the column in \code{data} that contains data about the binary treatment variable. 
#' @param hasbeensorted variable that only has internal usage for optimization purposes. There should be no need for a user to toggle this
#' 
#' @return \code{get.matchedsets} returns a "matched set" object, which primarily contains a named list of vectors. Each vector is a "matched set" containing the unit ids included in a matched set. The list names will indicate an i,t pair (formatted as "<i variable>.<t variable>") to which the vector/matched set corresponds.
#'
#' @examples \dontrun{
#' uid <-unique(dem$wbcode2)[1:10]
#' subdem <- dem[dem$wbcode2 %in% uid, ]
#' mset <- get.matchedsets(1992, 4, subdem, 4, "year", "wbcode2", "dem")
#' 
#' treateds <- findAllTreated(subdem, "dem", "year", "wbcode2")
#' msets <- get.matchedsets(treateds$year, treateds$wbcode2, subdem, 4, "year", "wbcode2", "dem")
#' }
#' @export
get.matchedsets <- function(t, id, data, L, t.column, id.column, treatedvar, hasbeensorted = FALSE) 
{
  if(!hasbeensorted)
  {
    data <- data[order(data[,id.column], data[,t.column]), ]  
  }
  # Verifying that time and unit data are integers -- perhaps later shift this to an automatic conversion process?
  if( any(head(data[, id.column]) %% 1 != 0) ) stop("unit data are not integer") # just doing the first few to check for efficiency purposes. 
  if( any(head(data[, t.column]) %% 1 != 0) ) stop("time data are not integer") 
  
  d <- data[, c(id.column, t.column, treatedvar)]
  d <- as.matrix(d)
  if(!is.numeric(d)) stop('data in treated, time, or id columns is not numeric')
  
  
  control.histories <- get_comparison_histories(d, t, id, which(colnames(d) == t.column) - 1 , which(colnames(d) == id.column) - 1, L, which(colnames(d) == treatedvar) - 1) #control histories should be a list
  compmat <- data.table::dcast(data.table::as.data.table(d), formula = paste0(id.column, "~", t.column), value.var = treatedvar) #reshape the data so each row corresponds to a unit, columns specify treatment over time
  t.map <- match(t, unique(d[, t.column])) #unique() should preserve orderings
  sets <- get_msets_helper(control.histories, as.matrix(compmat), t.map, id, L)
  named.sets <- matched_set(matchedsets = sets, id = id, t = t, L = L, t.var = t.column, id.var = id.column, treated.var = treatedvar)
  return(named.sets)
}
