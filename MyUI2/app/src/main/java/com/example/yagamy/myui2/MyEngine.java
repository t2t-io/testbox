package com.example.yagamy.myui2;

import org.json.JSONException;
import org.liquidplayer.webkit.javascriptcore.JSContext;
import org.liquidplayer.webkit.javascriptcore.JSObject;
import org.liquidplayer.webkit.javascriptcore.JSValue;
import org.liquidplayer.webkit.javascriptcore.JSException;
import org.json.JSONArray;
import org.json.JSONObject;

/**
 * The Engine to wrapper CB1 javascript engine.
 *
 * Created by yagamy on 2/14/16.
 */
public class MyEngine {

    private JSContext context = new JSContext();
    private JSValue entry = null;
    private JSObject entryFunc = null;
    private JSException lastException = null;

    public final static int CONSTANT_FLUSH_TYPE_BY_DEMAND = 1;  // by_demand
    public final static int CONSTANT_FLUSH_TYPE_IMMEDIATE = 2;  // immediate
    public final static int CONSTANT_FLUSH_TYPE_SMART = 3;      // smart
    public final static String BLUETOOTH_LA_BEST_007 = "la_best_007";

    private void invokeEntry(String name) throws Exception {
        Object[] parameters = {};
        invokeEntry(name, parameters);
    }

    private void invokeEntry(String name, Object[] parameters) throws Exception {
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

    private void engineInit(String bluetooth, int flushType, boolean uuencoded) throws Exception {
        JSONObject opts = new JSONObject();
        opts.put("ble", bluetooth);
        switch (flushType) {
            case CONSTANT_FLUSH_TYPE_BY_DEMAND:
                opts.put("flushType", "by_demand");
                break;
            case CONSTANT_FLUSH_TYPE_SMART:
                opts.put("flushType", "smart");
                break;
            case CONSTANT_FLUSH_TYPE_IMMEDIATE:
            default:
                opts.put("flushType", "immediate");
                break;
        }
        opts.put("uuencoded", new Boolean(uuencoded));
        JSONObject[] parameters = {opts};
        invokeEntry("init", parameters);
    }


    private void enginePerform(int id, int[] parameters, String[] parameter_names) throws Exception {
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
        invokeEntry("perform", params);
    }

    private void engineFlush() throws Exception {
        invokeEntry("flush");
    }

    public MyEngine(String script, String bluetooth, int flushType, boolean uuencoded) throws Exception {
        UnderscoreObject _ = new UnderscoreObject(context);
        context.property("_", _);
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

        engineInit(bluetooth, flushType, uuencoded);
    }

    public void test(int v) {
        try {
            int[] params = {v, 1};
            String[] param_names = {"value", "is_clockwise"};
            enginePerform(0x21, params, param_names);
        }
        catch (Exception ex) {
            ex.printStackTrace();
        }
    }

    public void testFlush() {
        try {
            engineFlush();
        }
        catch (Exception ex) {
            ex.printStackTrace();
        }
    }

    private interface Underscore {
        public void dbg(String line);
        public void invoke(String name_and_args);
    }

    private class UnderscoreObject extends JSObject implements Underscore {

        public UnderscoreObject(JSContext ctx) {
            super(ctx, Underscore.class);
        }

        @Override
        public void dbg(String line) {
            System.out.println("_[dbg]: " + line);
        }

        @Override
        public void invoke(String name_and_args) {
            System.out.println("_[invoke]: " + name_and_args);
        }
    }
}
