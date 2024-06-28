#include <mruby.h>
#include <mruby/array.h>
#include <mruby/error.h>
#include <mruby/hash.h>
#include <mruby/string.h>
#include <mruby/presym.h>
#include "yyjson.h"

typedef uint8_t parse_opts;
#define PARSE_OPTS_NONE 0
#define PARSE_OPTS_SYMBOLIZE_NAMES 1

#define mrb_yyjson_error(x) mrb_class_get_under_id(mrb, mrb_module_get_id(mrb, MRB_SYM(JSON)), MRB_SYM(x))
#define E_NESTING_ERROR mrb_yyjson_error(NestingError)
#define E_PARSER_ERROR mrb_yyjson_error(ParserError)

#define mrb_obj_to_s(mrb, obj) mrb_funcall(mrb, obj, "to_s", 0)

struct RException *mrb_yyjson_exc(mrb_state *mrb, struct RClass *exc, const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    mrb_value msg = mrb_vformat(mrb, fmt, args);
    va_end(args);

    return mrb_exc_ptr(mrb_exc_new_str(mrb, exc, msg));
}

mrb_value mrb_json_value_to_mrb_value(mrb_state *mrb, yyjson_val *val, parse_opts opts)
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
            mrb_ary_push(mrb, result, mrb_json_value_to_mrb_value(mrb, v, opts));
        }
        break;
    case YYJSON_TYPE_OBJ:
        result = mrb_hash_new_capa(mrb, yyjson_obj_size(val));

        yyjson_val *key;
        yyjson_obj_iter oi = yyjson_obj_iter_with(val);
        while ((key = yyjson_obj_iter_next(&oi)))
        {
            yyjson_val *v = yyjson_obj_iter_get_val(key);

            const char *key_str = yyjson_get_str(key);
            mrb_value k = opts & PARSE_OPTS_SYMBOLIZE_NAMES ? mrb_symbol_value(mrb_intern_cstr(mrb, key_str)) : mrb_str_new_cstr(mrb, key_str);
            mrb_hash_set(mrb, result, k, mrb_json_value_to_mrb_value(mrb, v, opts));
        }
        break;
    default:
        mrb_raise(mrb, E_NOTIMP_ERROR, "not implemented");
        break;
    }
    return result;
}

mrb_value mrb_yyjson_parse(mrb_state *mrb, mrb_value self)
{
    char *source;
    mrb_value opts = mrb_nil_value();
    parse_opts parse_opts = PARSE_OPTS_NONE;

    mrb_get_args(mrb, "z|H", &source, &opts);

    if (mrb_type(opts) == MRB_TT_HASH)
    {
        mrb_value symbolize_names = mrb_hash_get(mrb, opts, mrb_symbol_value(mrb_intern_cstr(mrb, "symbolize_names")));
        if (mrb_test(symbolize_names))
        {
            parse_opts |= PARSE_OPTS_SYMBOLIZE_NAMES;
        }
    }

    yyjson_read_err err;
    yyjson_doc *doc = yyjson_read_opts(source, strlen(source), 0, NULL, &err);
    if (doc == NULL)
    {
        mrb_raisef(mrb, E_PARSER_ERROR, "failed to parse JSON: %s position: %d", err.msg, err.pos);
    }

    yyjson_val *root = yyjson_doc_get_root(doc);
    mrb_value result = mrb_json_value_to_mrb_value(mrb, root, parse_opts);

    yyjson_doc_free(doc);
    return result;
}

void mrb_mruby_yyjson_gem_init(mrb_state *mrb)
{
    struct RClass *json_mod = mrb_define_module_id(mrb, MRB_SYM(JSON));
    mrb_define_module_function_id(mrb, json_mod, MRB_SYM(parse), mrb_yyjson_parse, MRB_ARGS_REQ(1) | MRB_ARGS_OPT(1));
}

void mrb_mruby_yyjson_gem_final(mrb_state *mrb)
{
}
