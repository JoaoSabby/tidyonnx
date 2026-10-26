# Independent R wire helpers build external and malformed fixtures without the native encoder.
#' @title Encode a test Protocol Buffers varint
#' @description Nonnegative test identifiers are encoded independently from the native writer.
#' @param value A nonnegative numeric scalar.
#' @return A raw vector containing the varint.
#' @keywords internal
wire_varint <- function(value) {
  result <- raw()
  repeat {
    byte <- value %% 128
    value <- floor(value / 128)
    result <- c(result, as.raw(byte + if (value > 0) 128 else 0))
    if (value == 0) return(result)
  }
}

#' @title Encode a length-delimited test field
#' @description A field key and length prefix are attached to raw payload bytes.
#' @param tag An integer field number.
#' @param value A raw payload vector.
#' @return A complete length-delimited wire field.
#' @keywords internal
wire_message <- function(tag, value) {
  c(wire_varint(tag * 8 + 2), wire_varint(length(value)), value)
}

#' @title Decode independent test wire fields
#' @description Fixture fields are separated into decoded values and original byte sequences.
#' @param bytes A valid serialized fixture byte vector.
#' @return A list of tagged fields with original raw encodings.
#' @keywords internal
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

#' @title Modify a fixture tree operator
#' @description The first graph node is edited while unrelated model fields are retained.
#' @param bytes A valid fixture model byte vector.
#' @param edit A callback transforming the decoded node-field list.
#' @return A serialized model with the edited tree node.
#' @keywords internal
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

#' @title Modify an integer array in a fixture node
#' @description The independent writer constructs packed or unpacked repeated integer fields.
#' @param bytes A valid fixture model byte vector.
#' @param name An integer-array attribute name.
#' @param values Replacement nonnegative integer values.
#' @param unpacked Logical; whether the values use unpacked encoding.
#' @return A serialized model with the edited integer attribute.
#' @keywords internal
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

#' @title Replace a scalar or repeated ONNX test attribute
#' @description Construct independent wire payloads for graph-contract tests.
#' @param bytes A serialized fixture graph.
#' @param name The attribute name to replace.
#' @param payload A complete encoded attribute-value field.
#' @param type The declared ONNX AttributeProto type.
#' @return Raw bytes containing the modified graph.
#' @keywords internal
WireReplaceAttribute <- function(bytes, name, payload, type){
  wire_edit_node(bytes, function(node){
    for(index in seq_along(node)){
      if(node[[index]]$tag != 5) next
      fields <- wire_fields(node[[index]]$value)
      nameIndex <- which(vapply(fields, function(field) field$tag == 1, logical(1)))
      if(rawToChar(fields[[nameIndex]]$value) != name) next
      node[[index]]$raw <- wire_message(5, c(
        wire_message(1, charToRaw(name)), wire_varint(20 * 8), wire_varint(type), payload
      ))
    }
    node
  })
}
