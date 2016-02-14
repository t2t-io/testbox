package com.example.yagamy.myui2;

import org.json.JSONArray;
import org.json.JSONObject;
import org.json.JSONTokener;
import org.liquidplayer.webkit.javascriptcore.JSContext;
import org.liquidplayer.webkit.javascriptcore.JSException;
import org.liquidplayer.webkit.javascriptcore.JSObject;
import org.liquidplayer.webkit.javascriptcore.JSValue;

import java.io.ByteArrayOutputStream;
import java.util.StringTokenizer;

/**
 * Created by yagamy on 2/14/16.
 */
public class JavascriptEngine {
    private JSContext context = new JSContext();
    private JSValue entry = null;
    private JSObject entryFunc = null;
    private JSException lastException = null;
    private PlatformInterface platform = null;
    private UnderscoreObject _ = null;
    private MyEngine parent = null;

    public JavascriptEngine(MyEngine parent, String script, PlatformInterface platform) {
        this.parent = parent;
        this.platform = platform;
        this._ = new UnderscoreObject(context, this);
        context.property("_", this._);
        context.evaluateScript("function LOGGER(text) { _.dbg(text); }");
        context.evaluateScript("function INVOKE(name_and_args) { _.invoke(name_and_args); }");
        context.setExceptionHandler(new JSContext.IJSExceptionHandler() {
            @Override
            public void handle(JSException exception) {
                lastException = exception;
            }
        });
        context.evaluateScript(script);
        entry = context.property("entry");
        entryFunc = entry.toObject();
    }

    private void callEntry(String name) throws Exception {
        Object[] parameters = {};
        callEntry(name, parameters);
    }

    private void callEntry(String name, Object[] parameters) throws Exception {
        StringBuffer sb = new StringBuffer();
        JSONArray params = new JSONArray();
        for (Object p: parameters) {
            params.put(p);
        }
        sb.append(name);
        sb.append('\t');
        sb.append(params.toString());
        String name_and_args = sb.toString();
        JSValue[] args = {new JSValue(context, name_and_args)};
        System.out.println("invoke [" + name + "] => " + name_and_args);
        JSValue result = entryFunc.callAsFunction(context, args);
        if (lastException != null) {
            String message = lastException.toString();
            lastException.printStackTrace();
            lastException = null;
            System.out.println("invoke [" + name + "] exception: " + message);
            throw new Exception(message);
        }
        System.out.println("invoke [" + name + "] result: " + result.toString());
        String res = result.toString();
        if (!res.equals("success")) {
            throw new Exception("unexpected result: `" + res + "`");
        }
    }

    private void platformRequest(String name_and_args) throws Exception {
        StringTokenizer st = new StringTokenizer(name_and_args, "\t", false);
        String name = st.nextToken();
        String argsString = st.nextToken();
        JSONTokener jt = new JSONTokener(argsString);
        JSONArray args = (JSONArray) jt.nextValue();

        if (name.equals("ble_write_characteristic")) {
            JSONArray xs = args.getJSONArray(0);
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            for (int i = 0; i < xs.length(); i++) {
                bos.write(xs.getInt(i));
            }
            bos.flush();;
            byte[] bytes = bos.toByteArray();
            platform.bleWriteCharacteristic(parent, bytes);
        }
        else {
            System.out.println("_.invoke => name: " + name + ", args = " + args.toString());
        }
    }


    private interface Underscore {
        public void dbg(String line);
        public void invoke(String name_and_args);
    }

    private class UnderscoreObject extends JSObject implements Underscore {

        private JavascriptEngine js;

        public UnderscoreObject(JSContext ctx, JavascriptEngine js) {
            super(ctx, Underscore.class);
            this.js = js;
        }

        @Override
        public void dbg(String line) {
            js.platform.debug(js.parent, line);
        }

        @Override
        public void invoke(String name_and_args) {
            // System.out.println("_.invoke: " + name_and_args);
            try {
                js.platformRequest(name_and_args);
            }
            catch (Exception ex) {
                ex.printStackTrace();
            }
        }
    }


    public void init(String bluetooth, String flushType, boolean uuencoded) throws Exception {
        JSONObject opts = new JSONObject();
        opts.put("ble", bluetooth);
        opts.put("flushType", flushType);
        opts.put("uuencoded", new Boolean(uuencoded));
        JSONObject[] parameters = {opts};
        callEntry("init", parameters);
    }


    public void perform(int id, int[] parameters, String[] parameter_names) throws Exception {
        Object[] params = new Object[3];
        params[0] = new Integer(id);
        JSONArray xs = null;
        params[1] = xs = new JSONArray();
        for (int p: parameters) {
            xs.put(p);
        }
        params[2] = xs = new JSONArray();
        for (String s: parameter_names) {
            xs.put(s);
        }
        callEntry("perform", params);
    }


    public void flush() throws Exception {
        callEntry("flush");
    }


    public void resetState() throws Exception {
        callEntry("reset_state");
    }
}
