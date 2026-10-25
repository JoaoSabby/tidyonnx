// Decode a bounded ONNX tree graph into immutable arrays before any prediction.
#include "model.h"
#include <set>
#include <sstream>

namespace tidyonnx {
namespace {
std::vector<OnnxField> fields(OnnxSpan stream) {
  std::vector<OnnxField> result;
  OnnxField field;
  int status;
  while ((status = tidyonnx_next_field(&stream, &field)) == 1) result.push_back(field);
  require(status == 0, "Malformed or truncated ONNX Protocol Buffers data.");
  return result;
}
std::string text(const OnnxField& field) {
  require(field.wire == 2, "Invalid ONNX string wire type.");
  std::string value(reinterpret_cast<const char*>(field.bytes.data), field.bytes.size);
  require(value.find('\0') == std::string::npos, "ONNX identifiers cannot contain NUL bytes.");
  return value;
}
int64_t integer(const OnnxField& field) {
  require(field.wire == 0, "Invalid ONNX integer wire type.");
  require(field.integer <= static_cast<uint64_t>(INT64_MAX), "Unsupported negative ONNX identifier.");
  return static_cast<int64_t>(field.integer);
}
// Both packed and unpacked repeated fields are legal protobuf encodings.
Attribute attribute(OnnxSpan span, std::string& name) {
  Attribute result;
  bool value_present = false;
  for (const auto& field : fields(span)) {
    if (field.tag == 1) name = text(field);
    else if (field.tag == 20) result.type = static_cast<int>(integer(field));
    else if (field.tag == 3) {
      result.integers.push_back(integer(field));
      value_present = true;
    } else if (field.tag == 4 || field.tag == 9) {
      result.strings.push_back(text(field));
      value_present = true;
    } else if (field.tag == 7 || field.tag == 8) {
      value_present = true;
      if (field.tag == 7 && field.wire == 5) result.floats.push_back(field.floating);
      else if (field.tag == 8 && field.wire == 0) result.integers.push_back(integer(field));
      else {
        require(field.wire == 2, "Invalid packed ONNX attribute.");
        OnnxSpan packed = field.bytes;
        while (packed.size) {
          if (field.tag == 7) {
            float value;
            require(tidyonnx_read_packed_float(&packed, &value), "Truncated ONNX float array.");
            result.floats.push_back(value);
          } else {
            uint64_t value;
            require(tidyonnx_read_packed_integer(&packed, &value) &&
              value <= static_cast<uint64_t>(INT64_MAX), "Invalid ONNX integer array.");
            result.integers.push_back(static_cast<int64_t>(value));
          }
        }
      }
    } else if (field.tag == 2 && field.wire == 5) {
      result.floats.push_back(field.floating);
      value_present = true;
    } else if (field.tag != 13) {
      throw std::runtime_error("Unsupported tensor-valued or referenced ONNX attribute.");
    }
  }
  require(!name.empty() && value_present && result.type >= 1 && result.type <= 8,
    "Invalid or unsupported ONNX attribute.");
  require((result.type == 2 || result.type == 7) ? result.floats.empty() && result.strings.empty() :
    (result.type == 1 || result.type == 6) ? result.integers.empty() && result.strings.empty() :
    (result.type == 3 || result.type == 8) && result.integers.empty() && result.floats.empty(),
    "ONNX attribute values do not match their declared type.");
  return result;
}
const Attribute& get(const std::map<std::string, Attribute>& attributes,
    const std::string& name) {
  auto found = attributes.find(name);
  require(found != attributes.end(), "Missing ONNX attribute: " + name);
  return found->second;
}
std::vector<std::string> split_names(const std::string& value) {
  std::vector<std::string> result;
  std::istringstream stream(value);
  std::string line;
  while (std::getline(stream, line)) result.push_back(line);
  return result;
}
// Only a dense float [N,P] input is accepted; preprocessing graphs are never skipped.
int input_schema(OnnxSpan span, std::string& name) {
  int element_type = 0;
  std::vector<int64_t> dimensions;
  for (const auto& field : fields(span)) {
    if (field.tag == 1) name = text(field);
    if (field.tag != 2) continue;
    for (const auto& type : fields(field.bytes)) {
      require(type.tag == 1 && type.wire == 2, "Only dense tensor inputs are supported.");
      for (const auto& tensor : fields(type.bytes)) {
        if (tensor.tag == 1) element_type = static_cast<int>(integer(tensor));
        if (tensor.tag != 2) continue;
        for (const auto& dimension : fields(tensor.bytes)) {
          if (dimension.tag != 1) continue;
          int64_t value = -1;
          for (const auto& item : fields(dimension.bytes)) {
            if (item.tag == 1) value = integer(item);
          }
          dimensions.push_back(value);
        }
      }
    }
  }
  require(element_type == 1 && dimensions.size() == 2 && dimensions[1] > 0 &&
    dimensions[1] <= INT_MAX && dimensions[0] == -1,
    "Expected a float32 [N, P] input with dynamic rows and a known feature count.");
  return static_cast<int>(dimensions[1]);
}
int mode_code(const std::string& mode) {
  const std::vector<std::string> modes = {"LEAF", "BRANCH_LT", "BRANCH_LEQ",
    "BRANCH_GT", "BRANCH_GTE", "BRANCH_EQ", "BRANCH_NEQ"};
  auto found = std::find(modes.begin(), modes.end(), mode);
  require(found != modes.end(), "Unsupported ONNX branch mode: " + mode);
  return static_cast<int>(found - modes.begin());
}
}

std::unique_ptr<Session> decode_model(const uint8_t* data, size_t size) {
  auto session = std::make_unique<Session>();
  std::map<std::string, std::string> metadata;
  OnnxSpan graph{nullptr, 0};
  bool have_graph = false;
  std::set<std::string> domains;
  for (const auto& field : fields({data, size})) {
    if (field.tag == ONNX_IR_VERSION) session->ir_version = static_cast<int>(integer(field));
    else if (field.tag == ONNX_PRODUCER_NAME) session->producer = text(field);
    else if (field.tag == ONNX_GRAPH) {
      require(field.wire == 2 && !have_graph, "Expected exactly one ONNX graph.");
      graph = field.bytes;
      have_graph = true;
    } else if (field.tag == ONNX_OPSET_IMPORT) {
      std::string domain;
      int version = 0;
      for (const auto& item : fields(field.bytes)) {
        if (item.tag == 1) domain = text(item);
        if (item.tag == 2) version = static_cast<int>(integer(item));
      }
      require(domains.insert(domain).second, "Duplicate ONNX opset domain.");
      if (domain.empty()) session->opset = version;
      else if (domain == "ai.onnx.ml") session->ml_opset = version;
      else throw std::runtime_error("Unsupported ONNX operator domain: " + domain);
    } else if (field.tag == ONNX_METADATA_PROPS) {
      std::string key;
      std::string value;
      for (const auto& item : fields(field.bytes)) {
        if (item.tag == 1) key = text(item);
        if (item.tag == 2) value = text(item);
      }
      require(!key.empty() && metadata.emplace(key, value).second, "Invalid duplicate ONNX metadata.");
    }
  }
  require(have_graph && session->ir_version >= 3 && session->ir_version <= 10 &&
    session->ml_opset >= 1 && session->ml_opset <= 3 &&
    (session->opset == 0 || session->opset <= 21), "Unsupported ONNX IR or opset version.");
  std::vector<OnnxSpan> graph_nodes;
  std::vector<OnnxSpan> inputs;
  std::vector<std::string> graph_outputs;
  std::vector<OnnxSpan> output_schemas;
  for (const auto& field : fields(graph)) {
    if (field.tag == ONNX_GRAPH_NODE) graph_nodes.push_back(field.bytes);
    else if (field.tag == ONNX_GRAPH_INPUT) inputs.push_back(field.bytes);
    else if (field.tag == ONNX_GRAPH_OUTPUT) {
      output_schemas.push_back(field.bytes);
      std::string name;
      for (const auto& item : fields(field.bytes)) if (item.tag == 1) name = text(item);
      graph_outputs.push_back(name);
    } else if (field.tag == ONNX_GRAPH_INITIALIZER || field.tag == 15) {
      throw std::runtime_error("Initializer and sparse-initializer graphs are not supported.");
    }
  }
  require((graph_nodes.size() == 1 || graph_nodes.size() == 2) && inputs.size() == 1,
    "Route A supports one TreeEnsemble node, optionally followed by Sigmoid, and one input.");
  int num_features = input_schema(inputs.front(), session->input_name);
  require(!session->input_name.empty(), "ONNX input name is empty.");
  std::map<std::string, Attribute> attributes;
  std::vector<std::string> node_inputs;
  std::string operation;
  std::string domain;
  for (const auto& field : fields(graph_nodes.front())) {
    if (field.tag == ONNX_NODE_INPUT) node_inputs.push_back(text(field));
    else if (field.tag == ONNX_NODE_OUTPUT) session->output_names.push_back(text(field));
    else if (field.tag == ONNX_NODE_OP_TYPE) operation = text(field);
    else if (field.tag == ONNX_NODE_DOMAIN) domain = text(field);
    else if (field.tag == ONNX_NODE_ATTRIBUTE) {
      std::string name;
      Attribute value = attribute(field.bytes, name);
      require(attributes.emplace(name, std::move(value)).second, "Duplicate ONNX node attribute.");
    }
  }
  bool classifier = operation == "TreeEnsembleClassifier";
  require(domain == "ai.onnx.ml" && (classifier || operation == "TreeEnsembleRegressor"),
    "Unsupported operator; expected ai.onnx.ml::TreeEnsembleClassifier or TreeEnsembleRegressor.");
  bool explicit_sigmoid = graph_nodes.size() == 2;
  session->num_graph_nodes = static_cast<int>(graph_nodes.size());
  if (explicit_sigmoid) {
    std::vector<std::string> sigmoid_inputs;
    std::vector<std::string> sigmoid_outputs;
    std::string sigmoid_operation;
    std::string sigmoid_domain;
    for (const auto& field : fields(graph_nodes[1])) {
      if (field.tag == ONNX_NODE_INPUT) sigmoid_inputs.push_back(text(field));
      else if (field.tag == ONNX_NODE_OUTPUT) sigmoid_outputs.push_back(text(field));
      else if (field.tag == ONNX_NODE_OP_TYPE) sigmoid_operation = text(field);
      else if (field.tag == ONNX_NODE_DOMAIN) sigmoid_domain = text(field);
      else require(field.tag == ONNX_NODE_NAME || field.tag == 6,
        "Unsupported trailing graph operator field.");
    }
    require(!classifier && sigmoid_operation == "Sigmoid" && sigmoid_domain.empty() &&
      sigmoid_inputs == session->output_names && sigmoid_outputs == graph_outputs &&
      sigmoid_inputs.size() == 1 && sigmoid_outputs.size() == 1 && session->opset >= 6,
      "Only a standard Sigmoid directly following regression is supported.");
    session->output_names = sigmoid_outputs;
  }
  require(node_inputs.size() == 1 && node_inputs[0] == session->input_name &&
    graph_outputs == session->output_names && graph_outputs.size() == (classifier ? 2U : 1U),
    "ONNX graph inputs and outputs do not match the tree operator.");
  const std::set<std::string> allowed = {
    "nodes_treeids", "nodes_nodeids", "nodes_featureids", "nodes_values", "nodes_modes",
    "nodes_truenodeids", "nodes_falsenodeids", "nodes_missing_value_tracks_true",
    "nodes_hitrates", "class_treeids", "class_nodeids", "class_ids", "class_weights",
    "classlabels_int64s", "classlabels_strings", "target_treeids", "target_nodeids",
    "target_ids", "target_weights", "n_targets", "base_values", "post_transform",
    "aggregate_function"
  };
  for (const auto& item : attributes) {
    require(allowed.count(item.first) != 0, "Unsupported ONNX attribute: " + item.first);
  }
  if (attributes.count("aggregate_function")) {
    require(get(attributes, "aggregate_function").strings == std::vector<std::string>{"SUM"},
      "Only SUM tree aggregation is supported.");
  }
  if (attributes.count("post_transform")) {
    const auto& transform = get(attributes, "post_transform").strings;
    require(transform.size() == 1, "Invalid post_transform.");
    if (transform[0] == "LOGISTIC") session->transform = 1;
    else if (transform[0] == "SOFTMAX") session->transform = 2;
    else require(transform[0] == "NONE", "Unsupported ONNX post_transform.");
  }
  if (explicit_sigmoid) {
    require(session->transform == 0, "Sigmoid must follow an untransformed regressor.");
    session->transform = 1;
  }
  if (classifier) {
    require(attributes.count("classlabels_int64s") != attributes.count("classlabels_strings"),
      "Expected exactly one set of class labels.");
    if (attributes.count("classlabels_int64s")) {
      for (auto label : get(attributes, "classlabels_int64s").integers) {
        session->class_levels.push_back(std::to_string(label));
      }
    } else {
      session->class_levels = get(attributes, "classlabels_strings").strings;
      session->label_type = "string";
    }
    require(session->class_levels.size() >= 2 && session->class_levels.size() <= 10000,
      "Invalid ONNX class count.");
    session->num_targets = static_cast<int>(session->class_levels.size());
    session->task_type = session->num_targets == 2 ? "classification_binary" : "classification_multiclass";
  } else {
    const auto& targets = get(attributes, "n_targets").integers;
    require(targets.size() == 1 && targets[0] == 1,
      "Only single-output regression is supported.");
    session->task_type = "regression";
  }
  // Validate declared output tensors rather than inventing inspection schemas.
  for (size_t output = 0; output < output_schemas.size(); ++output) {
    int element_type = 0;
    std::vector<int64_t> dimensions;
    for (const auto& value : fields(output_schemas[output])) {
      if (value.tag != 2) continue;
      for (const auto& type : fields(value.bytes)) {
        require(type.tag == 1 && type.wire == 2, "Only dense tensor outputs are supported.");
        for (const auto& tensor : fields(type.bytes)) {
          if (tensor.tag == 1) element_type = static_cast<int>(integer(tensor));
          if (tensor.tag != 2) continue;
          for (const auto& dimension : fields(tensor.bytes)) {
            if (dimension.tag != 1) continue;
            int64_t width = -1;
            for (const auto& item : fields(dimension.bytes)) {
              if (item.tag == 1) width = integer(item);
            }
            dimensions.push_back(width);
          }
        }
      }
    }
    bool label = classifier && output == 0;
    int expected_type = label ? (attributes.count("classlabels_strings") ? 8 : 7) : 1;
    require(element_type == expected_type && !dimensions.empty() && dimensions[0] == -1 &&
      (label ? dimensions.size() == 1 :
        (dimensions.size() == 2 && dimensions[1] == session->num_targets)),
      "ONNX output schema does not match the tree operator.");
  }
  session->base_values.assign(session->num_targets, 0.0f);
  if (attributes.count("base_values")) {
    const auto& base = get(attributes, "base_values").floats;
    require(base.size() == static_cast<size_t>(session->num_targets), "Invalid base_values length.");
    session->base_values = base;
    // Two-score binary base values are ambiguous across runtime implementations.
    if (classifier && session->num_targets == 2) {
      require(std::all_of(base.begin(), base.end(), [](float x) { return x == 0; }),
        "Two-class base_values are ambiguous; encode the intercept as a constant tree.");
    }
  }
  const auto& tree_ids = get(attributes, "nodes_treeids").integers;
  const auto& node_ids = get(attributes, "nodes_nodeids").integers;
  const auto& feature_ids = get(attributes, "nodes_featureids").integers;
  const auto& values = get(attributes, "nodes_values").floats;
  const auto& modes = get(attributes, "nodes_modes").strings;
  const auto& true_ids = get(attributes, "nodes_truenodeids").integers;
  const auto& false_ids = get(attributes, "nodes_falsenodeids").integers;
  std::vector<int64_t> missing(tree_ids.size(), 0);
  if (attributes.count("nodes_missing_value_tracks_true")) {
    missing = get(attributes, "nodes_missing_value_tracks_true").integers;
  }
  size_t count = tree_ids.size();
  require(count && count <= static_cast<size_t>(INT_MAX) && node_ids.size() == count &&
    feature_ids.size() == count && values.size() == count && modes.size() == count &&
    true_ids.size() == count && false_ids.size() == count && missing.size() == count,
    "ONNX node attribute arrays have inconsistent lengths.");
  std::map<std::pair<int64_t, int64_t>, int> positions;
  for (size_t index = 0; index < count; ++index) {
    require(positions.emplace(std::make_pair(tree_ids[index], node_ids[index]),
      static_cast<int>(index)).second, "Duplicate tree/node identifier.");
  }
  session->nodes.resize(count);
  std::vector<int> indegree(count, 0);
  for (size_t index = 0; index < count; ++index) {
    TidyOnnxNode node{};
    node.mode = mode_code(modes[index]);
    require(std::isfinite(values[index]) && (missing[index] == 0 || missing[index] == 1),
      "Nonfinite threshold or invalid missing-value direction.");
    node.threshold = values[index];
    node.missing_true = static_cast<int>(missing[index]);
    if (node.mode) {
      require(feature_ids[index] >= 0 && feature_ids[index] < num_features,
        "Tree feature index is outside the input schema.");
      node.feature = static_cast<int>(feature_ids[index]);
      auto yes = positions.find({tree_ids[index], true_ids[index]});
      auto no = positions.find({tree_ids[index], false_ids[index]});
      require(yes != positions.end() && no != positions.end() && yes->second != no->second,
        "Tree refers to missing or repeated child nodes.");
      node.true_child = yes->second;
      node.false_child = no->second;
      require(++indegree[node.true_child] == 1 && ++indegree[node.false_child] == 1,
        "Tree nodes must have exactly one parent.");
    }
    session->nodes[index] = node;
  }
  // Validate each connected tree iteratively to prevent stack overflow on deep input.
  std::set<int64_t> rooted_trees;
  for (const auto& position : positions) {
    int index = position.second;
    if (indegree[index] == 0) {
      require(rooted_trees.insert(position.first.first).second, "A tree has multiple roots.");
      session->roots.push_back(index);
    }
  }
  require(!session->roots.empty(), "Tree graph has no root.");
  std::vector<bool> visited(count, false);
  std::vector<int> pending = session->roots;
  size_t visited_count = 0;
  while (!pending.empty()) {
    int index = pending.back();
    pending.pop_back();
    require(!visited[index], "Cyclic ONNX tree graph.");
    visited[index] = true;
    ++visited_count;
    const auto& node = session->nodes[index];
    if (node.mode) {
      pending.push_back(node.true_child);
      pending.push_back(node.false_child);
    }
  }
  require(visited_count == count, "ONNX tree graph contains unreachable or cyclic nodes.");
  std::string prefix = classifier ? "class_" : "target_";
  const auto& weight_trees = get(attributes, prefix + "treeids").integers;
  const auto& weight_nodes = get(attributes, prefix + "nodeids").integers;
  const auto& weight_targets = get(attributes, prefix + "ids").integers;
  const auto& weight_values = get(attributes, prefix + "weights").floats;
  require(weight_trees.size() == weight_nodes.size() && weight_nodes.size() == weight_targets.size() &&
    weight_targets.size() == weight_values.size() && !weight_values.empty(),
    "ONNX leaf weight arrays have inconsistent lengths.");
  std::vector<std::vector<TidyOnnxWeight>> node_weights(count);
  std::set<std::pair<int, int>> assigned;
  std::vector<bool> target_used(session->num_targets, false);
  for (size_t index = 0; index < weight_values.size(); ++index) {
    auto found = positions.find({weight_trees[index], weight_nodes[index]});
    int64_t target = weight_targets[index];
    require(found != positions.end() && session->nodes[found->second].mode == 0 &&
      target >= 0 && target < session->num_targets && std::isfinite(weight_values[index]),
      "Invalid ONNX leaf weight reference.");
    require(assigned.insert({found->second, static_cast<int>(target)}).second,
      "Duplicate class or target weight at a leaf.");
    node_weights[found->second].push_back({static_cast<int>(target), weight_values[index]});
    target_used[target] = true;
  }
  require(!classifier || session->num_targets != 2 || (target_used[0] && target_used[1]),
    "Single-score binary classifiers are not supported; use explicit two-class scores.");
  session->weights.reserve(weight_values.size());
  for (size_t index = 0; index < count; ++index) {
    auto& node = session->nodes[index];
    require(node.mode || !node_weights[index].empty(), "Leaf node has no output weights.");
    node.weight_start = session->weights.size();
    node.weight_count = node_weights[index].size();
    session->weights.insert(session->weights.end(), node_weights[index].begin(), node_weights[index].end());
  }
  if (metadata.count("tidyonnx.source_class")) session->source_class = metadata["tidyonnx.source_class"];
  if (metadata.count("tidyonnx.task_type")) {
    const auto& task = metadata["tidyonnx.task_type"];
    require(task == session->task_type || (classifier && task == "classification_multiclass"),
      "ONNX task metadata contradicts the graph.");
    session->task_type = task;
  }
  if (metadata.count("tidyonnx.feature_names")) {
    session->feature_names = split_names(metadata["tidyonnx.feature_names"]);
  } else {
    for (int index = 0; index < num_features; ++index) session->feature_names.push_back("f" + std::to_string(index));
  }
  require(session->feature_names.size() == static_cast<size_t>(num_features),
    "Feature metadata does not match the input tensor.");
  if (classifier && metadata.count("tidyonnx.class_levels")) {
    auto labels = split_names(metadata["tidyonnx.class_levels"]);
    require(labels.size() == session->class_levels.size(), "Class metadata does not match the graph.");
    session->class_levels = labels;
  }
  for (const auto* names : {&session->feature_names, &session->class_levels}) {
    std::set<std::string> unique;
    for (const auto& name : *names) {
      require(!name.empty() && unique.insert(name).second, "Invalid or duplicate feature/class name.");
    }
  }
  for (float base : session->base_values) require(std::isfinite(base), "Nonfinite base value.");
  return session;
}
}
