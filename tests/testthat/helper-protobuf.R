# Independent R wire helpers build external and malformed fixtures without the native encoder.
wire_varint <- function(value) {
  result <- raw()
  repeat {
    byte <- value %% 128
    value <- floor(value / 128)
    result <- c(result, as.raw(byte + if (value > 0) 128 else 0))
    if (value == 0) return(result)
  }
}

wire_message <- function(tag, value) {
  c(wire_varint(tag * 8 + 2), wire_varint(length(value)), value)
}

wire_fields <- function(bytes) {
  position <- 1L
  read_integer <- function() {
    value <- 0
    multiplier <- 1
    repeat {
      byte <- as.integer(bytes[position])
      position <<- position + 1L
      value <- value + (byte %% 128) * multiplier
      if (byte < 128) return(value)
      multiplier <- multiplier * 128
    }
  }
  result <- list()
  while (position <= length(bytes)) {
    start <- position
    key <- read_integer()
    tag <- floor(key / 8)
    wire <- key %% 8
    if (wire == 2) {
      size <- read_integer()
      value <- if (size) bytes[position + seq_len(size) - 1L] else raw()
      position <- position + size
    } else if (wire == 0) {
      value_start <- position
      read_integer()
      value <- bytes[seq.int(value_start, position - 1L)]
    } else {
      size <- if (wire == 5) 4L else 8L
      value <- bytes[position + seq_len(size) - 1L]
      position <- position + size
    }
    result[[length(result) + 1L]] <- list(tag = tag, wire = wire, value = value,
      raw = bytes[seq.int(start, position - 1L)])
  }
  result
}

wire_edit_node <- function(bytes, edit) {
  model <- wire_fields(bytes)
  graph_index <- which(vapply(model, function(field) field$tag == 7, logical(1)))
  graph <- wire_fields(model[[graph_index]]$value)
  node_index <- which(vapply(graph, function(field) field$tag == 1, logical(1)))[1L]
  node <- edit(wire_fields(graph[[node_index]]$value))
  graph[[node_index]]$raw <- wire_message(1, do.call(c, lapply(node, "[[", "raw")))
  model[[graph_index]]$raw <- wire_message(7, do.call(c, lapply(graph, "[[", "raw")))
  do.call(c, lapply(model, "[[", "raw"))
}

wire_edit_attribute <- function(bytes, name, values, unpacked = FALSE) {
  wire_edit_node(bytes, function(node) {
    for (index in seq_along(node)) {
      if (node[[index]]$tag != 5) next
      attribute <- wire_fields(node[[index]]$value)
      found_name <- rawToChar(attribute[[which(vapply(attribute,
        function(field) field$tag == 1, logical(1)))]]$value)
      if (found_name != name) next
      attribute <- Filter(function(field) field$tag != 8, attribute)
      payload <- if (unpacked) do.call(c, lapply(values, function(value) {
        c(wire_varint(8 * 8), wire_varint(value))
      })) else wire_message(8, do.call(c, lapply(values, wire_varint)))
      node[[index]]$raw <- wire_message(5,
        c(do.call(c, lapply(attribute, "[[", "raw")), payload))
    }
    node
  })
}
