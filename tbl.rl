/*
* Copyright (c) 2010-2015 somemetricprefix <somemetricprefix+code@gmail.com>
*
* Permission to use, copy, modify, and distribute this software for any
* purpose with or without fee is hereby granted, provided that the above
* copyright notice and this permission notice appear in all copies.
*
* THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
* WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
* ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
* WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
* ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
* OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*/

#include "tbl.h"

#include <stdbool.h>

%% machine bencode;
%% write data;

static int parse(char *buf, size_t length,
                 const struct tbl_callbacks *callbacks, void *ctx)
{
  bool integer_negative = false;
  int64_t integer_value = 0;

  int cs;
  char *p = buf;
  char *pe = p + length;
  char *eof = pe;

%%{
  action error {
    return TBL_E_INVALID_DATA;
  }

  action update {
    integer_value = integer_value * 10 + (fc - '0');
  }

  action integer_parsed {
    if (integer_negative) {
      integer_value = -integer_value;
    }

    if (callbacks->integer && callbacks->integer(ctx, integer_value) != 0) {
      return TBL_E_CANCELED_BY_USER;
    }
  }

  action skip_string {
    // String larger than remaining buffer.
    if (integer_value >= pe - p) {
      return TBL_E_INVALID_DATA;
    }

    if (callbacks->string
        && callbacks->string(ctx, p + 1, (size_t)integer_value) != 0) {
      return TBL_E_CANCELED_BY_USER;
    }

    // Advance parser pointer by string lenght.
    p += integer_value;
  }

  integer = 'i'
            ( '0'
            | ('-'? @{ integer_negative = true; }
              [1-9] @update ([0-9]@update)*)
            )
            'e' @integer_parsed;

  string = digit+ @update ':' @skip_string;

  main := (integer | string)* $!error;

  write init;
  write exec;
}%%

  return TBL_E_NONE;
}

int tbl_parse(char *buf, size_t length, const struct tbl_callbacks *callbacks,
              void *ctx)
{
  if (!callbacks) {
    return TBL_E_NO_CALLBACKS;
  }

  return parse(buf, length, callbacks, ctx);
}
