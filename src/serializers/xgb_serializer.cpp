// Native XGBoost adapter and ONNX encoder, independent of the inference engine.
#include "../model.h"
#include "../nanopb/pb_encode.h"
#include <climits>
#include <cstring>
#include <set>

namespace tidyonnx {
namespace {
class ProtoWriter {
 public:
  std::vector<uint8_t> bytes;
  // A small initial capacity avoids repeated allocation for model header fields.
  ProtoWriter() { bytes.reserve(256); }
  // Nanopb writes directly into the owning vector, preserving exception safety.
  static bool append(pb_ostream_t* stream, const pb_byte_t* buffer, size_t count) {
    auto* destination = static_cast<std::vector<uint8_t>*>(stream->state);
    destination->insert(destination->end(), buffer, buffer + count);
    return true;
  }
  // Each stream borrows the same vector while Nanopb tracks write bounds.
  pb_ostream_t stream() {
    pb_ostream_t result{};
    result.callback = append;
    result.state = &bytes;
    result.max_size = SIZE_MAX;
    return result;
  }
  // Encode a tagged unsigned wire integer for schema-defined integer fields.
  void integer(uint32_t tag, uint64_t value) {
    auto output = stream();
    require(pb_encode_tag(&output, PB_WT_VARINT, tag) && pb_encode_varint(&output, value),
      "Cannot encode ONNX integer.");
  }
  // Packed repeated integers omit individual field tags.
  void raw_integer(uint64_t value) {
    auto output = stream();
    require(pb_encode_varint(&output, value), "Cannot encode ONNX packed integer.");
  }
  // ONNX float attributes retain the trained model's single-precision values.
  void raw_float(float value) {
    auto output = stream();
    require(pb_encode_fixed32(&output, &value), "Cannot encode ONNX float.");
  }
  // Length-delimited fields carry nested messages and UTF-8 identifiers.
  void data(uint32_t tag, const uint8_t* value, size_t size) {
    auto output = stream();
    require(pb_encode_tag(&output, PB_WT_STRING, tag) && pb_encode_string(&output, value, size),
      "Cannot encode ONNX byte field.");
  }
  // Strings use their UTF-8 byte length without locale-dependent transformations.
  void string(uint32_t tag, const std::string& value) {
    data(tag, reinterpret_cast<const uint8_t*>(value.data()), value.size());
  }
  // Nested wire messages are copied into the owning model buffer.
  void message(uint32_t tag, const ProtoWriter& value) {
    data(tag, value.bytes.data(), value.bytes.size());
  }
};
// XGBoost scalar strings must be non-missing and decoded explicitly as UTF-8.
std::string scalar_string(SEXP value) {
  require(TYPEOF(value) == STRSXP && Rf_xlength(value) == 1 && STRING_ELT(value, 0) != NA_STRING,
    "Expected a scalar string in the XGBoost model.");
  return Rf_translateCharUTF8(STRING_ELT(value, 0));
}
// Accept the scalar encodings emitted by supported XGBoost JSON model versions.
double number(SEXP value) {
  require(Rf_xlength(value) == 1, "Expected a scalar XGBoost number.");
  double result;
  if (TYPEOF(value) == REALSXP) result = REAL(value)[0];
  else if (TYPEOF(value) == INTSXP) result = INTEGER(value)[0];
  else if (TYPEOF(value) == LGLSXP) result = LOGICAL(value)[0];
  else if (TYPEOF(value) == STRSXP) {
    std::string text = scalar_string(value);
    size_t used;
    result = std::stod(text, &used);
    require(used == text.size(), "Invalid XGBoost numeric string.");
  } else throw std::runtime_error("Invalid XGBoost numeric value.");
  require(std::isfinite(result), "Nonfinite value in XGBoost model.");
  return result;
}
// Identifiers require exact bounded integers before entering tree-index arrays.
int integer_number(SEXP value) {
  double result = number(value);
  require(result >= INT_MIN && result <= INT_MAX && result == std::floor(result),
    "Invalid integer in XGBoost model.");
  return static_cast<int>(result);
}
// Required structural fields fail before partially encoded trees can escape.
cpp11::list list_field(cpp11::list object, const char* name) {
  SEXP value = object[name];
  require(TYPEOF(value) == VECSXP, std::string("Missing XGBoost structure: ") + name);
  return cpp11::list(value);
}
// Ordered names use a delimiter that is explicitly forbidden within each name.
std::string join_names(cpp11::strings names) {
  std::string result;
  for (R_xlen_t index = 0; index < names.size(); ++index) {
    SEXP value = names[index];
    std::string name = Rf_translateCharUTF8(value);
    require(!name.empty() && name.find('\n') == std::string::npos &&
      name.find('\r') == std::string::npos, "Feature and class names cannot contain line breaks.");
    if (index) result += '\n';
    result += name;
  }
  return result;
}
// Typed integer attributes share one packed encoding across all objectives.
void attribute_integers(ProtoWriter& node, const std::string& name,
    const std::vector<int64_t>& values) {
  ProtoWriter attribute;
  attribute.string(1, name);
  attribute.integer(20, 7);
  ProtoWriter packed;
  for (auto value : values) packed.raw_integer(static_cast<uint64_t>(value));
  attribute.message(8, packed);
  node.message(ONNX_NODE_ATTRIBUTE, attribute);
}
// Typed float attributes preserve thresholds, leaf weights and intercept values.
void attribute_floats(ProtoWriter& node, const std::string& name,
    const std::vector<float>& values) {
  ProtoWriter attribute;
  attribute.string(1, name);
  attribute.integer(20, 6);
  ProtoWriter packed;
  for (float value : values) packed.raw_float(value);
  attribute.message(7, packed);
  node.message(ONNX_NODE_ATTRIBUTE, attribute);
}
// Repeated strings encode the operator's ordered node comparison modes.
void attribute_strings(ProtoWriter& node, const std::string& name,
    const std::vector<std::string>& values) {
  ProtoWriter attribute;
  attribute.string(1, name);
  attribute.integer(20, 8);
  for (const auto& value : values) attribute.string(9, value);
  node.message(ONNX_NODE_ATTRIBUTE, attribute);
}
// Scalar operator attributes declare score transforms and aggregation semantics.
void attribute_string(ProtoWriter& node, const std::string& name, const std::string& value) {
  ProtoWriter attribute;
  attribute.string(1, name);
  attribute.integer(20, 3);
  attribute.string(4, value);
  node.message(ONNX_NODE_ATTRIBUTE, attribute);
}
// Scalar integer attributes declare target counts without string coercion.
void attribute_integer(ProtoWriter& node, const std::string& name, int value) {
  ProtoWriter attribute;
  attribute.string(1, name);
  attribute.integer(20, 2);
  attribute.integer(3, value);
  node.message(ONNX_NODE_ATTRIBUTE, attribute);
}
// Exported tensors share the symbolic batch axis and an explicit known feature width.
ProtoWriter value_info(const std::string& name, int type, int columns, bool matrix) {
  ProtoWriter value;
  value.string(1, name);
  ProtoWriter tensor_type;
  tensor_type.integer(1, type);
  ProtoWriter shape;
  ProtoWriter rows;
  rows.string(2, "N");
  shape.message(1, rows);
  if (matrix) {
    ProtoWriter width;
    width.integer(1, columns);
    shape.message(1, width);
  }
  tensor_type.message(2, shape);
  ProtoWriter type_info;
  type_info.message(1, tensor_type);
  value.message(2, type_info);
  return value;
}
// Portable task metadata remains independent of any live R model or recipe object.
void metadata_entry(ProtoWriter& model, const std::string& key, const std::string& value) {
  ProtoWriter entry;
  entry.string(1, key);
  entry.string(2, value);
  model.message(ONNX_METADATA_PROPS, entry);
}
struct Objective {
  std::string name;
  bool classifier;
  bool binary;
  bool logit_base;
  std::string transform;
};
const std::vector<Objective> objectives = {
  {"binary:logistic", true, true, true, "LOGISTIC"},
  {"binary:logitraw", false, false, false, "NONE"},
  {"reg:squarederror", false, false, false, "NONE"},
  {"reg:logistic", false, false, true, "LOGISTIC"},
  {"multi:softprob", true, false, false, "SOFTMAX"},
  {"multi:softmax", true, false, false, "SOFTMAX"}
};
class XgboostSerializer final : public Serializer {
 public:
  // The source identifier describes the fitted engine handled by this adapter.
  const char* source_class() const override { return "xgb.Booster"; }
  // Shared traversal and objective metadata preserve numerical score conventions.
  SerializedModel serialize(cpp11::list learner, cpp11::strings features,
      cpp11::strings levels, cpp11::doubles base_score, int opset, int ir_version,
      const std::string& target_name, int positive_class) const override {
    cpp11::list objective = list_field(learner, "objective");
    std::string objective_name = scalar_string(objective["name"]);
    auto found = std::find_if(objectives.begin(), objectives.end(), [&](const Objective& value) {
      return value.name == objective_name;
    });
    require(found != objectives.end(), "Unsupported XGBoost objective: " + objective_name);
    const Objective& specification = *found;
    cpp11::list model_parameters = list_field(learner, "learner_model_param");
    SEXP target_count = model_parameters["num_target"];
    require(Rf_isNull(target_count) || integer_number(target_count) == 1,
      "Vector-output XGBoost models are not supported.");
    int num_classes = integer_number(model_parameters["num_class"]);
    int targets = specification.classifier ? (specification.binary ? 2 : num_classes) : 1;
    require(targets >= 1 && targets <= 10000 &&
      (!specification.classifier || levels.size() == targets), "Invalid XGBoost target count.");
    require(base_score.size() == 1 || base_score.size() == (specification.binary ? 1 : targets),
      "XGBoost base_score has an unsupported length.");
    std::vector<float> base_values(targets, 0.0f);
    for (int target = 0; target < targets; ++target) {
      double value = base_score[base_score.size() == 1 ? 0 : target];
      require(std::isfinite(value), "Nonfinite base_score.");
      if (specification.logit_base) {
        require(value > 0 && value < 1, "A logistic base_score must lie strictly between 0 and 1.");
        value = std::log(value / (1 - value));
      }
      base_values[target] = static_cast<float>(value);
    }
    require(positive_class == 0 || positive_class == 1, "Invalid binary positive class.");
    if (specification.binary) {
      float positive_base = base_values[1];
      base_values[positive_class] = positive_base;
      base_values[1 - positive_class] = -positive_base;
    }
    else if (specification.classifier && targets == 2) {
      float half_difference = (base_values[1] - base_values[0]) * 0.5f;
      base_values[0] = -half_difference;
      base_values[1] = half_difference;
    }
    cpp11::list booster = list_field(learner, "gradient_booster");
    require(scalar_string(booster["name"]) == "gbtree",
      "Only gbtree boosters are supported; dart and gblinear require distinct serializers.");
    cpp11::list tree_model = list_field(booster, "model");
    cpp11::list trees = list_field(tree_model, "trees");
    cpp11::list tree_info = list_field(tree_model, "tree_info");
    require(trees.size() == tree_info.size() && trees.size() > 0, "Invalid XGBoost tree assignment.");
    std::vector<int64_t> tree_ids, node_ids, feature_ids, true_ids, false_ids, missing;
    std::vector<float> thresholds;
    std::vector<std::string> modes;
    std::vector<int64_t> weight_trees, weight_nodes, weight_ids;
    std::vector<float> weights;
    // Explicit two-class scores avoid the positive-only-weight special case in ORT.
    // A constant intercept tree also avoids its ambiguous binary base_values handling.
    if (specification.classifier) {
      tree_ids.push_back(0);
      node_ids.push_back(0);
      feature_ids.push_back(0);
      true_ids.push_back(0);
      false_ids.push_back(0);
      missing.push_back(0);
      thresholds.push_back(0);
      modes.push_back("LEAF");
      for (int target = 0; target < targets; ++target) {
        weight_trees.push_back(0);
        weight_nodes.push_back(0);
        weight_ids.push_back(target);
        weights.push_back(base_values[target]);
      }
    }
    for (R_xlen_t tree_index = 0; tree_index < trees.size(); ++tree_index) {
      cpp11::list tree(trees[tree_index]);
      cpp11::list parameters = list_field(tree, "tree_param");
      require(integer_number(parameters["size_leaf_vector"]) <= 1,
        "Vector-leaf trees are not supported.");
      cpp11::list left = list_field(tree, "left_children");
      cpp11::list right = list_field(tree, "right_children");
      cpp11::list split_indices = list_field(tree, "split_indices");
      cpp11::list split_conditions = list_field(tree, "split_conditions");
      cpp11::list default_left = list_field(tree, "default_left");
      cpp11::list split_type = list_field(tree, "split_type");
      size_t count = static_cast<size_t>(left.size());
      require(count && right.size() == left.size() && split_indices.size() == left.size() &&
        split_conditions.size() == left.size() && default_left.size() == left.size() &&
        split_type.size() == left.size(), "Inconsistent XGBoost tree array lengths.");
      require(count <= static_cast<size_t>(INT_MAX), "XGBoost tree is too large.");
      // Reserve one entry per stored node and visit only nodes reachable after pruning.
      size_t capacity = tree_ids.size() + count;
      tree_ids.reserve(capacity);
      node_ids.reserve(capacity);
      feature_ids.reserve(capacity);
      true_ids.reserve(capacity);
      false_ids.reserve(capacity);
      missing.reserve(capacity);
      thresholds.reserve(capacity);
      modes.reserve(capacity);
      std::vector<bool> visited(count, false);
      std::vector<int> pending{0};
      int target = integer_number(tree_info[tree_index]);
      require(target >= 0 && target < (specification.binary ? 1 : targets),
        "Invalid XGBoost tree-to-class assignment.");
      int64_t tree_id = tree_index + (specification.classifier ? 1 : 0);
      while (!pending.empty()) {
        int node = pending.back();
        pending.pop_back();
        require(node >= 0 && static_cast<size_t>(node) < count && !visited[node],
          "Invalid or cyclic XGBoost tree.");
        visited[node] = true;
        require(integer_number(split_type[node]) == 0, "Categorical XGBoost splits are not supported.");
        int yes = integer_number(left[node]);
        int no = integer_number(right[node]);
        bool leaf = yes == -1;
        require(leaf ? no == -1 : (yes >= 0 && no >= 0 && yes != no), "Invalid XGBoost child indices.");
        int feature = leaf ? 0 : integer_number(split_indices[node]);
        require(feature >= 0 && feature < features.size(), "Invalid XGBoost split feature.");
        double value = number(split_conditions[node]);
        float encoded = static_cast<float>(value);
        require(std::isfinite(encoded), "XGBoost node value exceeds float32 range.");
        tree_ids.push_back(tree_id);
        node_ids.push_back(node);
        feature_ids.push_back(feature);
        thresholds.push_back(leaf ? 0.0f : encoded);
        modes.push_back(leaf ? "LEAF" : "BRANCH_LT");
        true_ids.push_back(leaf ? 0 : yes);
        false_ids.push_back(leaf ? 0 : no);
        missing.push_back(leaf ? 0 : integer_number(default_left[node]));
        if (leaf) {
          if (specification.classifier && targets == 2) {
            float positive_weight = specification.binary ? encoded :
              (target == 1 ? encoded * 0.5f : -encoded * 0.5f);
            for (int output = 0; output < 2; ++output) {
              weight_trees.push_back(tree_id);
              weight_nodes.push_back(node);
              weight_ids.push_back(output);
              int positive = specification.binary ? positive_class : 1;
              weights.push_back(output == positive ? positive_weight : -positive_weight);
            }
          } else {
            weight_trees.push_back(tree_id);
            weight_nodes.push_back(node);
            weight_ids.push_back(target);
            weights.push_back(encoded);
          }
        } else {
          pending.push_back(no);
          pending.push_back(yes);
        }
      }
    }
    bool explicit_sigmoid = objective_name == "reg:logistic";
    ProtoWriter node;
    node.string(ONNX_NODE_INPUT, "features");
    if (specification.classifier) node.string(ONNX_NODE_OUTPUT, "label");
    node.string(ONNX_NODE_OUTPUT, specification.classifier ? "probabilities" : (explicit_sigmoid ? "margin" : "prediction"));
    node.string(ONNX_NODE_NAME, "xgboost_ensemble");
    node.string(ONNX_NODE_OP_TYPE, specification.classifier ? "TreeEnsembleClassifier" : "TreeEnsembleRegressor");
    node.string(ONNX_NODE_DOMAIN, "ai.onnx.ml");
    attribute_integers(node, "nodes_treeids", tree_ids);
    attribute_integers(node, "nodes_nodeids", node_ids);
    attribute_integers(node, "nodes_featureids", feature_ids);
    attribute_floats(node, "nodes_values", thresholds);
    attribute_strings(node, "nodes_modes", modes);
    attribute_integers(node, "nodes_truenodeids", true_ids);
    attribute_integers(node, "nodes_falsenodeids", false_ids);
    attribute_integers(node, "nodes_missing_value_tracks_true", missing);
    std::string prefix = specification.classifier ? "class_" : "target_";
    attribute_integers(node, prefix + "treeids", weight_trees);
    attribute_integers(node, prefix + "nodeids", weight_nodes);
    attribute_integers(node, prefix + "ids", weight_ids);
    attribute_floats(node, prefix + "weights", weights);
    attribute_string(node, "post_transform", explicit_sigmoid ? "NONE" : specification.transform);
    if (specification.classifier) {
      std::vector<int64_t> labels;
      for (int target = 0; target < targets; ++target) labels.push_back(target);
      attribute_integers(node, "classlabels_int64s", labels);
    } else {
      attribute_integer(node, "n_targets", 1);
      attribute_string(node, "aggregate_function", "SUM");
      attribute_floats(node, "base_values", base_values);
    }
    ProtoWriter graph;
    graph.message(ONNX_GRAPH_NODE, node);
    // Scalar TreeEnsembleRegressor LOGISTIC is ignored by some reference runtimes.
    // An explicit standard-domain Sigmoid preserves portable regression semantics.
    if (explicit_sigmoid) {
      ProtoWriter sigmoid;
      sigmoid.string(ONNX_NODE_INPUT, "margin");
      sigmoid.string(ONNX_NODE_OUTPUT, "prediction");
      sigmoid.string(ONNX_NODE_OP_TYPE, "Sigmoid");
      sigmoid.string(ONNX_NODE_NAME, "logistic_response");
      graph.message(ONNX_GRAPH_NODE, sigmoid);
    }
    graph.string(ONNX_GRAPH_NAME, "tidyonnx_xgboost");
    graph.message(ONNX_GRAPH_INPUT, value_info("features", 1, static_cast<int>(features.size()), true));
    if (specification.classifier) {
      graph.message(ONNX_GRAPH_OUTPUT, value_info("label", 7, 1, false));
      graph.message(ONNX_GRAPH_OUTPUT, value_info("probabilities", 1, targets, true));
    } else graph.message(ONNX_GRAPH_OUTPUT, value_info("prediction", 1, 1, true));
    ProtoWriter model;
    model.integer(ONNX_IR_VERSION, ir_version);
    model.string(ONNX_PRODUCER_NAME, "tidyonnx");
    model.string(ONNX_PRODUCER_VERSION, "0.2.0");
    model.message(ONNX_GRAPH, graph);
    ProtoWriter standard_opset;
    standard_opset.integer(2, opset);
    model.message(ONNX_OPSET_IMPORT, standard_opset);
    ProtoWriter ml_opset;
    ml_opset.string(1, "ai.onnx.ml");
    ml_opset.integer(2, 3);
    model.message(ONNX_OPSET_IMPORT, ml_opset);
    metadata_entry(model, "tidyonnx.source_class", source_class());
    metadata_entry(model, "tidyonnx.task_type", specification.classifier ?
      (specification.binary ? "classification_binary" : "classification_multiclass") : "regression");
    metadata_entry(model, "tidyonnx.feature_names", join_names(features));
    if (specification.classifier) metadata_entry(model, "tidyonnx.class_levels", join_names(levels));
    metadata_entry(model, "tidyonnx.objective", objective_name);
    metadata_entry(model, "tidyonnx.target_name", target_name);
    metadata_entry(model, "tidyonnx.binary_positive_class", std::to_string(positive_class));
    metadata_entry(model, "tidyonnx.num_trees",
      std::to_string(trees.size() + (specification.classifier ? 1 : 0)));
    metadata_entry(model, "tidyonnx.num_nodes", std::to_string(node_ids.size()));
    metadata_entry(model, "tidyonnx.num_graph_nodes", explicit_sigmoid ? "2" : "1");
    metadata_entry(model, "tidyonnx.opset", std::to_string(opset));
    metadata_entry(model, "tidyonnx.ml_opset", "3");
    metadata_entry(model, "tidyonnx.ir_version", std::to_string(ir_version));
    metadata_entry(model, "tidyonnx.binary_encoding", "explicit_two_class_scores_constant_intercept");
    return {std::move(model.bytes)};
  }
};
}
// The immutable adapter is shared without retaining a fitted model or runtime session.
const Serializer& xgboost_serializer() {
  static const XgboostSerializer serializer;
  return serializer;
}
}
