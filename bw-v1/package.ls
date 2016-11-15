#!/usr/bin/env lsc -cj
#

# Known issue:
#   when executing the `package.ls` directly, there is always error
#   "/usr/bin/env: lsc -cj: No such file or directory", that is because `env`
#   doesn't allow space.
#
#   More details are discussed on StackOverflow:
#     http://stackoverflow.com/questions/3306518/cannot-pass-an-argument-to-python-with-usr-bin-env-python
#
#   The alternative solution is to add `envns` script to /usr/bin directory
#   to solve the _no space_ issue.
#
#   Or, you can simply type `lsc -cj package.ls` to generate `package.json`
#   quickly.
#

# package.json
#
name: \bw

author:
  name: ['Yagamy']
  email: 'yagamy@gmail.com'

description: 'blue web'

version: \1.0.0

repository:
  type: \git
  url: ''

main: \index

engines:
  node: \4.4.x

dependencies:
  async: \^2.1.2
  mkdirp: \^0.5.1
  colors: \1.1.2
  lodash: \^4.11.1
  noble: \^1.7.0
  express: \*
  "livescript-middleware": \^1.1.2
  "socket.io": \^1.5.1
  "socket.io-client": \^1.5.1


optionalDependencies: {}
