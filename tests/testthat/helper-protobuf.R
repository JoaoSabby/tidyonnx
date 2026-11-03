# Independent R wire helpers build external and malformed fixtures without the native encoder.
onnx_internal_wire_varint <- function(value) {
  result <- raw()
  repeat {
    byte <- value %% 128
    value <- floor(value / 128)
    result <- c(result, as.raw(byte + if (value > 0) 128 else 0))
    if (value == 0) return(result)
  }
}

onnx_internal_wire_message <- function(tag, value) {
  c(onnx_internal_wire_varint(tag * 8 + 2), onnx_internal_wire_varint(length(value)), value)
}

onnx_internal_wire_fields <- function(bytes) {
  position <- 1L
  onnx_internal_read_integer <- function() {
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
    key <- onnx_internal_read_integer()
    tag <- floor(key / 8)
    wire <- key %% 8
    if (wire == 2) {
      size <- onnx_internal_read_integer()
      value <- if (size) bytes[position + seq_len(size) - 1L] else raw()
      position <- position + size
    } else if (wire == 0) {
      value_start <- position
      onnx_internal_read_integer()
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

onnx_internal_wire_edit_node <- function(bytes, edit) {
  model <- onnx_internal_wire_fields(bytes)
  graph_index <- which(vapply(model, function(field) field$tag == 7, logical(1)))
  graph <- onnx_internal_wire_fields(model[[graph_index]]$value)
  node_index <- which(vapply(graph, function(field) field$tag == 1, logical(1)))[1L]
  node <- edit(onnx_internal_wire_fields(graph[[node_index]]$value))
  graph[[node_index]]$raw <- onnx_internal_wire_message(1, do.call(c, lapply(node, "[[", "raw")))
  model[[graph_index]]$raw <- onnx_internal_wire_message(7, do.call(c, lapply(graph, "[[", "raw")))
  do.call(c, lapply(model, "[[", "raw"))
}

onnx_internal_wire_edit_attribute <- function(bytes, name, values, unpacked = FALSE) {
  onnx_internal_wire_edit_node(bytes, function(node) {
    # Each field is transformed independently; unrelated attributes remain unchanged.
    lapply(node, function(field) {
      if (field$tag != 5) return(field)
      attribute <- onnx_internal_wire_fields(field$value)
      found_name <- rawToChar(attribute[[which(vapply(attribute,
        function(field) field$tag == 1, logical(1)))]]$value)
      if (found_name != name) return(field)
      attribute <- Filter(function(field) field$tag != 8, attribute)
      payload <- if (unpacked) do.call(c, lapply(values, function(value) {
        c(onnx_internal_wire_varint(8 * 8), onnx_internal_wire_varint(value))
      })) else onnx_internal_wire_message(8, do.call(c, lapply(values, onnx_internal_wire_varint)))
      field$raw <- onnx_internal_wire_message(5,
        c(do.call(c, lapply(attribute, "[[", "raw")), payload))
      field
    })
  })
}
