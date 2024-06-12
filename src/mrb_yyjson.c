#include <mruby.h>
#include <mruby/array.h>
#include <mruby/hash.h>
#include <mruby/string.h>
#include "yyjson.h"

#ifndef MRB_YYJSON_MAx_NESTING
#define MRB_YYJSON_MAx_NESTING 100
#endif

mrb_value mrb_json_value_to_mrb_value(mrb_state *mrb, yyjson_val *val)
{
    mrb_value result;

    switch (yyjson_get_type(val))
    {
    case YYJSON_TYPE_NULL:
        result = mrb_nil_value();
        break;
    case YYJSON_TYPE_BOOL:
        result = yyjson_is_true(val) ? mrb_true_value() : mrb_false_value();
        break;
    case YYJSON_TYPE_NUM:
        if (yyjson_is_uint(val))
        {
            result = mrb_fixnum_value(yyjson_get_uint(val));
        }
        else if (yyjson_is_sint(val))
        {
            result = mrb_fixnum_value(yyjson_get_sint(val));
        }
        else
        {
            result = mrb_float_value(mrb, yyjson_get_real(val));
        }
        break;
    case YYJSON_TYPE_STR:
        result = mrb_str_new_cstr(mrb, yyjson_get_str(val));
        break;
    case YYJSON_TYPE_ARR:
        result = mrb_ary_new_capa(mrb, yyjson_arr_size(val));

        yyjson_val *v;
        yyjson_arr_iter ai = yyjson_arr_iter_with(val);
        while ((v = yyjson_arr_iter_next(&ai)))
        {
            mrb_ary_push(mrb, result, mrb_json_value_to_mrb_value(mrb, v));
        }
        break;
    case YYJSON_TYPE_OBJ:
        result = mrb_hash_new_capa(mrb, yyjson_obj_size(val));

        yyjson_val *key;
        yyjson_obj_iter oi = yyjson_obj_iter_with(val);
        while ((key = yyjson_obj_iter_next(&oi)))
        {
            yyjson_val *v = yyjson_obj_iter_get_val(key);

            mrb_value k = mrb_json_value_to_mrb_value(mrb, key);
            mrb_hash_set(mrb, result, k, mrb_json_value_to_mrb_value(mrb, v));
        }
        break;
    default:
        mrb_raise(mrb, E_NOTIMP_ERROR, "not implemented");
        break;
    }
    return result;
}

yyjson_mut_val *mrb_value_to_json_value(mrb_state *mrb, yyjson_mut_doc *doc, mrb_value val, int depth)
{
    if (depth > MRB_YYJSON_MAx_NESTING)
    {
        struct RClass *json_mod = mrb_module_get(mrb, "JSON");
        struct RClass *nesting_error = mrb_class_get_under(mrb, json_mod, "NestingError");
        mrb_raisef(mrb, nesting_error, "nesting of %d is too deep", MRB_YYJSON_MAx_NESTING);
    }

    if (mrb_nil_p(val))
    {
        return yyjson_mut_null(doc);
    }

    yyjson_mut_val *result;
    switch (mrb_type(val))
    {
    case MRB_TT_FALSE:
        result = yyjson_mut_bool(doc, false);
        break;
    case MRB_TT_TRUE:
        result = yyjson_mut_bool(doc, true);
        break;
    case MRB_TT_FIXNUM:
        result = yyjson_mut_int(doc, mrb_fixnum(val));
        break;
    case MRB_TT_FLOAT:
        result = yyjson_mut_real(doc, mrb_float(val));
        break;
    case MRB_TT_STRING:
        result = yyjson_mut_str(doc, mrb_str_to_cstr(mrb, val));
        break;
    case MRB_TT_ARRAY:
        result = yyjson_mut_arr(doc);
        size_t arr_len = RARRAY_LEN(val);
        for (size_t i = 0; i < arr_len; i++)
        {
            mrb_value v = mrb_ary_ref(mrb, val, i);
            yyjson_mut_val *json_v = mrb_value_to_json_value(mrb, doc, v, depth + 1);
            yyjson_mut_arr_append(result, json_v);
        }
        break;
    case MRB_TT_HASH:
        result = yyjson_mut_obj(doc);
        mrb_value keys = mrb_hash_keys(mrb, val);
        size_t keys_len = RARRAY_LEN(keys);
        for (size_t i = 0; i < keys_len; i++)
        {
            mrb_value key = mrb_ary_ref(mrb, keys, i);
            mrb_value v = mrb_hash_get(mrb, val, key);
            yyjson_mut_val *json_k = mrb_value_to_json_value(mrb, doc, key, depth + 1);
            yyjson_mut_val *json_v = mrb_value_to_json_value(mrb, doc, v, depth + 1);
            yyjson_mut_obj_add(result, json_k, json_v);
        }
        break;
    default:
        result = yyjson_mut_str(doc, mrb_str_to_cstr(mrb, mrb_funcall(mrb, val, "to_s", 0)));
        break;
    }

    return result;
}

mrb_value mrb_yyjson_generate(mrb_state *mrb, mrb_value self)
{
    mrb_value obj;
    mrb_get_args(mrb, "o", &obj);

    yyjson_mut_doc *doc = yyjson_mut_doc_new(NULL);
    yyjson_mut_val *root = mrb_value_to_json_value(mrb, doc, obj, 0);
    yyjson_mut_doc_set_root(doc, root);

    mrb_value result = mrb_str_new_cstr(mrb, yyjson_mut_write(doc, 0, NULL));
    yyjson_mut_doc_free(doc);

    return result;
}

mrb_value mrb_yyjson_parse(mrb_state *mrb, mrb_value self)
{
    char *source;

    mrb_get_args(mrb, "z", &source);

    yyjson_read_err err;
    yyjson_doc *doc = yyjson_read_opts(source, strlen(source), 0, NULL, &err);
    if (doc == NULL)
    {
        mrb_raisef(mrb, E_RUNTIME_ERROR, "failed to parse JSON: %s", err.msg);
    }

    yyjson_val *root = yyjson_doc_get_root(doc);
    mrb_value result = mrb_json_value_to_mrb_value(mrb, root);

    yyjson_doc_free(doc);
    return result;
}

mrb_value mrb_yyjson_pretty_generate(mrb_state *mrb, mrb_value self)
{
    mrb_value obj;
    mrb_get_args(mrb, "o", &obj);

    yyjson_mut_doc *doc = yyjson_mut_doc_new(NULL);
    yyjson_mut_val *root = mrb_value_to_json_value(mrb, doc, obj, 0);
    yyjson_mut_doc_set_root(doc, root);

    mrb_value result = mrb_str_new_cstr(mrb, yyjson_mut_write(doc, YYJSON_WRITE_PRETTY_TWO_SPACES, NULL));
    yyjson_mut_doc_free(doc);

    return result;
}

void mrb_mruby_yyjson_gem_init(mrb_state *mrb)
{
    struct RClass *json_mod = mrb_define_module(mrb, "JSON");
    mrb_define_class_method(mrb, json_mod, "generate", mrb_yyjson_generate, MRB_ARGS_REQ(1));
    mrb_define_class_method(mrb, json_mod, "parse", mrb_yyjson_parse, MRB_ARGS_REQ(1));
    mrb_define_class_method(mrb, json_mod, "pretty_generate", mrb_yyjson_pretty_generate, MRB_ARGS_REQ(1));
}

void mrb_mruby_yyjson_gem_final(mrb_state *mrb)
{
}
