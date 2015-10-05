// Generated by LiveScript 1.4.0
(function(){
  var fs, path, async, settings, DEBUG, CHECK, LOAD_CONFIG, resource, exports;
  fs = require('fs');
  path = require('path');
  async = require('async');
  settings = {
    program_name: null,
    app_dir: null,
    work_dir: null,
    config_dir: null
  };
  DEBUG = function(message){
    if (process.env.VERBOSE) {
      return console.error(message);
    }
  };
  CHECK = function(p){
    var config_dir, log_dir, dirs, error;
    config_dir = path.resolve(p + "" + path.sep + "config");
    log_dir = path.resolve(p + "" + path.sep + "logs");
    DEBUG("checking " + path.resolve(p));
    try {
      dirs = fs.readdirSync(config_dir);
      if (!fs.existsSync(log_dir)) {
        fs.mkdirSync(log_dir);
      }
      settings.work_dir = p;
      settings.config_dir = config_dir;
      console.log("use " + path.resolve(p) + " as work_dir");
      return console.log("use " + settings.app_dir + " as app_dir");
    } catch (e$) {
      error = e$;
      return DEBUG("checking " + path.resolve(p) + " but failed");
    }
  };
  if (process.argv[1] != null) {
    settings.program_name = path.basename(process.argv[1]);
  } else {
    settings.program_name = "unknown";
  }
  if (process.argv[1] != null) {
    settings.app_dir = path.dirname(process.argv[1]);
  } else {
    settings.app_dir = process.cwd();
  }
  if (process.env['WORK_DIR'] != null) {
    CHECK(process.env['WORK_DIR']);
  }
  if (!settings.work_dir) {
    CHECK(path.resolve("."));
  }
  if (!settings.work_dir && process.argv[1] != null) {
    CHECK(path.dirname(process.argv[1]));
  }
  if (!settings.work_dir) {
    console.error("failed to find any work directory.");
    if (process.env.VERBOSE == null) {
      console.error("please re-run the program with environment variable VERBOSE=true to get further verbose messages...");
    }
    process.exit(1);
  }
  LOAD_CONFIG = function(p, callback){
    var found, config, error;
    found = false;
    try {
      config = p.json
        ? JSON.parse(fs.readFileSync(p.path))
        : require(p.path);
      found = true;
      callback(null, config);
    } catch (e$) {
      error = e$;
      DBG("failed to load " + p.path + " due to error: " + error);
    }
    return found;
  };
  resource = {
    /**
     * Dump all enviroment variables
     */
    dumpEnvs: function(){
      var i$, ref$, len$;
      for (i$ = 0, len$ = (ref$ = process.argv).length; i$ < len$; ++i$) {
        (fn$.call(this, i$, ref$[i$]));
      }
      DBG("process.execPath = " + process.execPath);
      DBG("process.arch = " + process.arch);
      DBG("process.platform = " + process.platform);
      DBG("process.cwd() = " + process.cwd());
      DBG("path.normalize('.') = " + path.normalize('.'));
      DBG("path.normalize(__dirname) = " + path.normalize(__dirname));
      DBG("path.resolve('.') = " + path.resolve('.'));
      return DBG("path.resolve(__dirname) = " + path.resolve(__dirname));
      function fn$(i, v){
        DBG("argv[" + i + "] = " + v);
      }
    }
    /**
     * Load configuration file from following files in order
     *   - ${config_dir}/${name}.ls
     *   - ${config_dir}/${name}.js
     *   - ${config_dir}/${name}.json
     *
     * @param name, the name of configuration file to be loaded.
     */,
    loadConfig: function(name, callback){
      var pathes, ret, i$, len$, p, text, error;
      pathes = [
        {
          path: settings.config_dir + "" + path.sep + name + ".ls",
          json: false
        }, {
          path: settings.config_dir + "" + path.sep + name + ".json",
          json: true
        }
      ];
      ret = {
        found: false,
        config: null
      };
      for (i$ = 0, len$ = pathes.length; i$ < len$; ++i$) {
        p = pathes[i$];
        if (ret.found) {
          continue;
        }
        try {
          DBG("try " + p.path + " ...");
          text = fs.readFileSync(p.path) + "";
          if (!p.json) {
            text = require('livescript').compile(text, {
              json: true
            });
          }
          ret.config = JSON.parse(text);
          ret.found = true;
        } catch (e$) {
          error = e$;
          console.log("stack: " + error.stack);
          continue;
        }
      }
      if (!ret.found) {
        DBG("cannot find config " + name);
      }
      return ret.config;
    }
    /**
     * Resolve to an absolute path to the file in the specified
     * `type` directory, related to work_dir.
     *
     * @param type, the type of directory, e.g. 'logs', 'scripts', ...
     * @param filename, the name of that file.
     */,
    resolveWorkPath: function(type, filename){
      return path.resolve(settings.work_dir + "" + path.sep + type + path.sep + filename);
    }
    /**
     * Resolve to an absolute path to the file in the specified
     * `type` directory, related to app_dir.
     *
     * @param type, the type of directory, e.g. 'logs', 'scripts', ...
     * @param filename, the name of that file.
     */,
    resolveResourcePath: function(type, filename){
      var ret;
      ret = path.resolve(settings.app_dir + "" + path.sep + type + path.sep + filename);
      return ret;
    }
    /**
     * Load javascript, livescript, or coffeescript from ${app_dir}/lib. For example,
     * when `loadScript 'foo'` is called, the function tries to load scripts one-by-one
     * as following order:
     *
     *    1. ${app_dir}/lib/foo.js
     *    2. ${app_dir}/lib/foo.ls
     *
     * @name {[type]}
     */,
    loadScript: function(name){
      return require(settings.app_dir + "" + path.sep + "lib" + path.sep + name);
    }
    /**
     * Load javascript, livescript, or coffeescript from ${app_dir}/lib/plugins. For example,
     * when `loadPlugin 'foo'` is called, the function tries to load scripts one-by-one
     * as following order:
     *
     *    1. ${app_dir}/lib/plugins/foo.js
     *    2. ${app_dir}/lib/plugins/foo.ls
     *    3. ${app_dir}/lib/plugins/foo/index.js
     *    4. ${app_dir}/lib/plugins/foo/index.ls
     *    5. ${esys_modules}/base/lib/plugins/foo.js
     *    6. ${esys_modules}/base/lib/plugins/foo.ls
     *    7. ${esys_modules}/base/lib/plugins/foo/index.js
     *    8. ${esys_modules}/base/lib/plugins/foo/index.ls
     *
     * @name {[type]}
     */,
    loadPlugin: function(name){
      var lib, plugins, errors, pathes, found, m, i$, len$, exx;
      lib = 'lib';
      plugins = 'plugins';
      errors = [];
      pathes = [settings.app_dir + "" + path.sep + lib + path.sep + plugins + path.sep + name, settings.app_dir + "" + path.sep + lib + path.sep + plugins + path.sep + name + path.sep + "index", __dirname + "" + path.sep + plugins + path.sep + name, __dirname + "" + path.sep + plugins + path.sep + name + path.sep + "index"];
      found = false;
      m = null;
      for (i$ = 0, len$ = pathes.length; i$ < len$; ++i$) {
        (fn$.call(this, i$, pathes[i$]));
      }
      if (found) {
        return m;
      }
      for (i$ = 0, len$ = errors.length; i$ < len$; ++i$) {
        (fn1$.call(this, i$, errors[i$]));
      }
      exx = errors.pop();
      throw exx.err;
      function fn$(i, p){
        var error, exx;
        if (!found) {
          try {
            m = require(p);
            found = true;
          } catch (e$) {
            error = e$;
            exx = {
              err: error,
              path: p
            };
            errors.push(exx);
          }
        }
      }
      function fn1$(i, exx){
        DBG("loading " + exx.path + " but err: " + exx.err);
      }
    }
    /**
     * Get the program name of entry javascript (livescript) for
     * nodejs to execute.
     */,
    getProgramName: function(){
      return settings.program_name;
    },
    getAppDir: function(){
      return settings.app_dir;
    },
    getWorkDir: function(){
      return settings.work_dir;
    }
  };
  module.exports = exports = resource;
}).call(this);
