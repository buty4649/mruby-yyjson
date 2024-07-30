#include <mruby.h>
#include <mruby/array.h>
#include <mruby/error.h>
#include <mruby/hash.h>
#include <mruby/string.h>
#include <mruby/variable.h>
#include <mruby/presym.h>
#include "yyjson.h"
#include "terminal_color.h"

#define mrb_json_module() mrb_obj_value(mrb_module_get_id(mrb, MRB_SYM(JSON)))
#define mrb_yyjson_error(x) mrb_class_get_under_id(mrb, mrb_module_get_id(mrb, MRB_SYM(JSON)), MRB_SYM(x))
#define E_GENERATOR_ERROR mrb_yyjson_error(GeneratorError)
#define E_NESTING_ERROR mrb_yyjson_error(NestingError)
#define E_PARSER_ERROR mrb_yyjson_error(ParserError)

#define mrb_obj_to_s(mrb, obj) mrb_funcall(mrb, obj, "to_s", 0)
#define mrb_obj_to_s_to_cstr(mrb, obj) mrb_str_to_cstr(mrb, mrb_funcall(mrb, obj, "to_s", 0))

struct RException *mrb_yyjson_exc(mrb_state *mrb, struct RClass *exc, const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    mrb_value msg = mrb_vformat(mrb, fmt, args);
    va_end(args);

    return mrb_exc_ptr(mrb_exc_new_str(mrb, exc, msg));
}

typedef uint32_t generator_flag;
#define GENERATOR_DEFAULT_MAX_NESTING 19
#define GENERATOR_FLAG_NONE 0
#define GENERATOR_FLAG_PRETTY (1 << 6) // = YYSON_WRITE_PRETTY_TWO_SPACES
#define GENERATOR_FLAG_COLOR (1 << 8)

static void *yyjson_mrb_malloc(void *ctx, size_t size)
{
    return mrb_malloc((mrb_state *)ctx, size);
}

static void *yyjson_mrb_realloc(void *ctx, void *ptr, size_t old_size, size_t size)
{
    return mrb_realloc((mrb_state *)ctx, ptr, size);
}

static void yyjson_mrb_free(void *ctx, void *ptr)
{
    mrb_free((mrb_state *)ctx, ptr);
}

typedef struct mrb_yyjson_generator_context
{
    generator_flag flg;
    yyjson_alc *alc;
    int depth;
    int max_nesting;
    struct RException *exc;
} mrb_yyjson_generator_context;

yyjson_mut_val *mrb_value_to_json_value(mrb_state *mrb, mrb_value obj, yyjson_mut_doc *doc, mrb_yyjson_generator_context *ctx)
{
    if (ctx->max_nesting > 0 && ctx->depth > ctx->max_nesting)
    {
        ctx->exc = mrb_yyjson_exc(mrb, E_NESTING_ERROR, "nesting of %d is too deep", ctx->depth);
        return NULL;
    }

    if (mrb_nil_p(obj))
    {
        if (ctx->flg & GENERATOR_FLAG_COLOR)
        {
            mrb_value color_null = mrb_funcall_id(mrb, mrb_json_module(), MRB_SYM(color_null), 0);
            mrb_value c = mrb_str_set_color(mrb, mrb_str_new_lit(mrb, "null"), color_null, mrb_nil_value(), mrb_nil_value());
            return yyjson_mut_raw(doc, RSTRING_PTR(c));
        }
        return yyjson_mut_null(doc);
    }

    yyjson_mut_val *result;
    switch (mrb_type(obj))
    {
    case MRB_TT_TRUE:
        if (ctx->flg & GENERATOR_FLAG_COLOR)
        {
            mrb_value color_boolean = mrb_funcall_id(mrb, mrb_json_module(), MRB_SYM(color_boolean), 0);
            mrb_value c = mrb_str_set_color(mrb, mrb_str_new_lit(mrb, "true"), color_boolean, mrb_nil_value(), mrb_nil_value());
            result = yyjson_mut_raw(doc, RSTRING_PTR(c));
        }
        else
        {
            result = yyjson_mut_bool(doc, true);
        }
        break;
    case MRB_TT_FALSE:
        if (ctx->flg & GENERATOR_FLAG_COLOR)
        {
            mrb_value color_boolean = mrb_funcall_id(mrb, mrb_json_module(), MRB_SYM(color_boolean), 0);
            mrb_value c = mrb_str_set_color(mrb, mrb_str_new_lit(mrb, "false"), color_boolean, mrb_nil_value(), mrb_nil_value());
            result = yyjson_mut_raw(doc, RSTRING_PTR(c));
        }
        else
        {
            result = yyjson_mut_bool(doc, false);
        }
        break;
    case MRB_TT_INTEGER:
    {
        mrb_value n = mrb_obj_to_s(mrb, obj);
        if (ctx->flg & GENERATOR_FLAG_COLOR)
        {
            mrb_value color_number = mrb_funcall_id(mrb, mrb_json_module(), MRB_SYM(color_number), 0);
            n = mrb_str_set_color(mrb, n, color_number, mrb_nil_value(), mrb_nil_value());
        }
        result = yyjson_mut_raw(doc, RSTRING_PTR(n));
        break;
    }
    case MRB_TT_FLOAT:
    {
        mrb_float f = mrb_float(obj);
        if (isnan(f))
        {
            ctx->exc = mrb_yyjson_exc(mrb, E_GENERATOR_ERROR, "NaN is not a valid number in JSON");
            return NULL;
        }
        else if (isinf(f))
        {
            ctx->exc = mrb_yyjson_exc(mrb, E_GENERATOR_ERROR, "Infinity is not a valid number in JSON");
            return NULL;
        }

        mrb_value number = mrb_obj_to_s(mrb, obj);
        if (ctx->flg & GENERATOR_FLAG_COLOR)
        {
            mrb_value color_number = mrb_funcall_id(mrb, mrb_json_module(), MRB_SYM(color_number), 0);
            number = mrb_str_set_color(mrb, number, color_number, mrb_nil_value(), mrb_nil_value());
        }
        result = yyjson_mut_raw(doc, RSTRING_PTR(number));
        break;
    }
    case MRB_TT_STRING:
        result = yyjson_mut_str(doc, mrb_str_to_cstr(mrb, obj));
        if (ctx->flg & GENERATOR_FLAG_COLOR)
        {
            yyjson_write_err err;
            char *json = yyjson_mut_val_write_opts(result, YYJSON_WRITE_NOFLAG, ctx->alc, NULL, &err);
            if (json == NULL)
            {
                ctx->exc = mrb_yyjson_exc(mrb, E_GENERATOR_ERROR, "failed to generate JSON: %s", err.msg);
                return NULL;
            }
            mrb_value color_string = mrb_funcall_id(mrb, mrb_json_module(), MRB_SYM(color_string), 0);
            mrb_value c = mrb_str_set_color(mrb, mrb_str_new_cstr(mrb, json), color_string, mrb_nil_value(), mrb_nil_value());
            result = yyjson_mut_raw(doc, RSTRING_PTR(c));
            yyjson_mrb_free(mrb, json);
        }
        break;

    case MRB_TT_ARRAY:
    {
        result = yyjson_mut_arr(doc);
        mrb_int len = RARRAY_LEN(obj);
        for (mrb_int i = 0; i < len; i++)
        {
            mrb_value v = mrb_ary_ref(mrb, obj, i);
            ctx->depth++;
            yyjson_mut_val *item = mrb_value_to_json_value(mrb, v, doc, ctx);
            ctx->depth--;
            if (item == NULL)
            {
                return NULL;
            }
            yyjson_mut_arr_append(result, item);
        }
        break;
    }

    case MRB_TT_HASH:
    {
        result = yyjson_mut_obj(doc);
        mrb_value keys = mrb_hash_keys(mrb, obj);
        mrb_int len = RARRAY_LEN(keys);
        for (mrb_int i = 0; i < len; i++)
        {
            mrb_value key = mrb_ary_ref(mrb, keys, i);
            mrb_value value = mrb_hash_get(mrb, obj, key);

            ctx->depth++;
            generator_flag old_flag = ctx->flg;
            ctx->flg &= ~GENERATOR_FLAG_COLOR;
            yyjson_mut_val *k = mrb_value_to_json_value(mrb, mrb_obj_to_s(mrb, key), doc, ctx);
            ctx->flg = old_flag;
            if (k == NULL)
            {
                ctx->depth--;
                return NULL;
            }
            if (ctx->flg & GENERATOR_FLAG_COLOR)
            {
                yyjson_write_err err;
                char *json_k = yyjson_mut_val_write_opts(k, YYJSON_WRITE_NOFLAG, ctx->alc, NULL, &err);
                if (json_k == NULL)
                {
                    ctx->exc = mrb_yyjson_exc(mrb, E_GENERATOR_ERROR, "failed to generate JSON: %s", err.msg);
                    return NULL;
                }
                mrb_value color_object_key = mrb_funcall_id(mrb, mrb_json_module(), MRB_SYM(color_object_key), 1, mrb_int_value(mrb, ctx->depth));
                mrb_value c = mrb_str_set_color(mrb, mrb_str_new_cstr(mrb, json_k), color_object_key, mrb_nil_value(), mrb_nil_value());

                k = yyjson_mut_raw(doc, RSTRING_PTR(c));
                yyjson_mrb_free(mrb, json_k);
            }

            yyjson_mut_val *v = mrb_value_to_json_value(mrb, value, doc, ctx);
            ctx->depth--;
            if (v == NULL)
            {
                return NULL;
            }
            unsafe_yyjson_mut_obj_add(result, k, v, unsafe_yyjson_get_len(result));
        }
        break;
    }

    default:
        result = mrb_value_to_json_value(mrb, mrb_obj_to_s(mrb, obj), doc, ctx);
    }

    return result;
}

void parse_generator_opts(mrb_state *mrb, mrb_value opts, mrb_yyjson_generator_context *ctx)
{
    if (!mrb_hash_p(opts))
    {
        return;
    }

    mrb_value max_nesting = mrb_hash_get(mrb, opts, mrb_symbol_value(mrb_intern_cstr(mrb, "max_nesting")));
    if (mrb_test(max_nesting))
    {
        if (mrb_fixnum_p(max_nesting))
        {
            ctx->max_nesting = mrb_fixnum(max_nesting);
            if (ctx->max_nesting < 0)
            {
                mrb_raise(mrb, E_ARGUMENT_ERROR, "max_nesting must be greater than or equal to 0");
            }
        }
        else
        {
            mrb_raise(mrb, E_TYPE_ERROR, "max_nesting must be a Fixnum");
        }
    }

    mrb_value pritty_print = mrb_hash_get(mrb, opts, mrb_symbol_value(mrb_intern_cstr(mrb, "pretty_print")));
    if (mrb_test(pritty_print))
    {
        ctx->flg |= GENERATOR_FLAG_PRETTY;
    }

    mrb_value colorize = mrb_hash_get(mrb, opts, mrb_symbol_value(mrb_intern_cstr(mrb, "colorize")));
    if (mrb_test(colorize))
    {
        ctx->flg |= GENERATOR_FLAG_COLOR;
    }
}

mrb_value mrb_value_to_json_string(mrb_state *mrb, generator_flag default_flg)
{
    mrb_value obj;
    mrb_value opts = mrb_nil_value();
    mrb_yyjson_generator_context ctx = {
        .flg = default_flg,
        .depth = 0,
        .max_nesting = GENERATOR_DEFAULT_MAX_NESTING,
        .exc = NULL,
    };

    mrb_get_args(mrb, "o|H", &obj, &opts);
    parse_generator_opts(mrb, opts, &ctx);

    yyjson_alc alc = {
        .malloc = yyjson_mrb_malloc,
        .realloc = yyjson_mrb_realloc,
        .free = yyjson_mrb_free,
        .ctx = (void *)mrb,
    };
    yyjson_mut_doc *doc = yyjson_mut_doc_new(&alc);
    yyjson_mut_val *root = mrb_value_to_json_value(mrb, obj, doc, &ctx);
    if (root == NULL)
    {
        yyjson_mut_doc_free(doc);
        mrb_exc_raise(mrb, mrb_obj_value(ctx.exc));
    }
    yyjson_mut_doc_set_root(doc, root);

    yyjson_write_err err;
    yyjson_write_flag write_flag = (ctx.flg & GENERATOR_FLAG_PRETTY) ? YYJSON_WRITE_PRETTY_TWO_SPACES : YYJSON_WRITE_NOFLAG;
    char *json = yyjson_mut_write_opts(doc, write_flag, &alc, NULL, &err);
    if (json == NULL)
    {
        yyjson_mut_doc_free(doc);
        mrb_raisef(mrb, E_NESTING_ERROR, "failed to generate JSON: %s", err.msg);
    }

    mrb_value result = mrb_str_new_cstr(mrb, json);
    yyjson_mrb_free(mrb, json);
    yyjson_mut_doc_free(doc);

    return result;
}

mrb_value mrb_yyjson_generate(mrb_state *mrb, mrb_value self)
{
    return mrb_value_to_json_string(mrb, GENERATOR_FLAG_NONE);
}

mrb_value mrb_yyjson_pretty_generate(mrb_state *mrb, mrb_value self)
{
    return mrb_value_to_json_string(mrb, GENERATOR_FLAG_PRETTY);
}

mrb_value mrb_yyjson_colorize_generate(mrb_state *mrb, mrb_value self)
{
    return mrb_value_to_json_string(mrb, GENERATOR_FLAG_PRETTY | GENERATOR_FLAG_COLOR);
}

typedef uint8_t parse_opts;
#define PARSE_OPTS_NONE 0
#define PARSE_OPTS_SYMBOLIZE_NAMES 1

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
    mrb_define_module_function_id(mrb, json_mod, MRB_SYM(generate), mrb_yyjson_generate, MRB_ARGS_REQ(1) | MRB_ARGS_OPT(1));
    mrb_define_module_function_id(mrb, json_mod, MRB_SYM(pretty_generate), mrb_yyjson_pretty_generate, MRB_ARGS_REQ(1) | MRB_ARGS_OPT(1));
    mrb_define_module_function_id(mrb, json_mod, MRB_SYM(colorize_generate), mrb_yyjson_colorize_generate, MRB_ARGS_REQ(1) | MRB_ARGS_OPT(1));
    mrb_define_module_function_id(mrb, json_mod, MRB_SYM(parse), mrb_yyjson_parse, MRB_ARGS_REQ(1) | MRB_ARGS_OPT(1));
}

void mrb_mruby_yyjson_gem_final(mrb_state *mrb)
{
}
