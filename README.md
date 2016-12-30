# Groonga and optimizer plugin

ANDクエリのOptimizer
ヒット数の少なそうなANDクエリが先に実行されるようにクエリの順番を書きかえる
selector関数の場合は最後に呼び出し順に実行される

実験用。 とりあえず、使いたい用途で使えるもの

## Install

Install Groonga using --enable-mruby option

Build this function.

    % sh autogen.sh
    % ./configure
    % sudo make install

## Usage

Register `expression_rewriters/and_optimizer`:

    % groonga DB
    > plugin_register expression_rewriters/and_optimizer

Create expression_rewriters table

```
table_create expression_rewriters TABLE_HASH_KEY ShortText
column_create expression_rewriters plugin_name COLUMN_SCALAR Text
load --table expression_rewriters
[
{"_key": "and_optimizer", "plugin_name": "expression_rewriters/and_optimizer"}
]
```

## License

LGPL 2.1. See COPYING for details.
