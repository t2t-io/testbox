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
name: \session-test

author:
  name: \yagamy
  email: 'yagamy@gmail.com'

description: "Session Test"

version: \0.1.0

repository:
  type: \git
  url: ''

main: \index

dependencies:
  express: \^4.0.0
  pug: \*
  \express-session : \^1.11.1
  \session-file-store : \*
  livescript: \1.5.0
  \uglify-js : \3.4.9
  mkdirp: \*
  emailjs: \*
  mysql: \*
  uuid: \*

optionalDependencies: {}
