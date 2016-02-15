package com.example.yagamy.myui2;

/**
 * The Engine to wrapper CB1 javascript engine.
 *
 * Created by yagamy on 2/14/16.
 */
public class MyEngine {

    public final static int CONSTANT_FLUSH_TYPE_BY_DEMAND = 1;  // by_demand
    public final static int CONSTANT_FLUSH_TYPE_IMMEDIATE = 2;  // immediate
    public final static int CONSTANT_FLUSH_TYPE_SMART = 3;      // smart
    public final static String BLUETOOTH_LA_BEST_007 = "la_best_007";

    private JavascriptEngine inner;

    public MyEngine(String script, String bluetooth, int flushType, boolean uuencoded, PlatformInterface platform) throws Exception {
        String type = "";
        switch (flushType) {
            case CONSTANT_FLUSH_TYPE_BY_DEMAND:
                type = "by_demand";
                break;
            case CONSTANT_FLUSH_TYPE_SMART:
                type = "smart";
                break;
            case CONSTANT_FLUSH_TYPE_IMMEDIATE:
            default:
                type = "immediate";
                break;
        }
        inner = new JavascriptEngine(this, script, platform);
        inner.init(bluetooth, type, uuencoded);
    }

    public void testMotor1(int v) {
        try {
            int[] params = {v, 1};
            String[] param_names = {"value", "is_clockwise"};
            inner.perform(0x21, params, param_names);
        }
        catch (Exception ex) {
            ex.printStackTrace();
        }
    }

    public void testMotor2(int v) {
        try {
            int[] params = {v, 1};
            String[] param_names = {"value", "is_clockwise"};
            inner.perform(0x22, params, param_names);
        }
        catch (Exception ex) {
            ex.printStackTrace();
        }
    }

    public void testFlush() {
        try {
            inner.flush();
        }
        catch (Exception ex) {
            ex.printStackTrace();
        }
    }


}
