package com.example.yagamy.myui2;

import android.os.Bundle;
import android.support.design.widget.FloatingActionButton;
import android.support.design.widget.Snackbar;
import android.support.v7.app.AppCompatActivity;
import android.support.v7.widget.Toolbar;
import android.view.View;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.SeekBar;
import android.widget.Button;
import org.liquidplayer.webkit.javascriptcore.JSContext;
import org.liquidplayer.webkit.javascriptcore.JSObject;
import org.liquidplayer.webkit.javascriptcore.JSValue;
import org.liquidplayer.webkit.javascriptcore.JSException;
import org.apache.commons.io.IOUtils;
import java.io.InputStream;

public class MainActivity extends AppCompatActivity {

    private JSContext js_context = new JSContext();
    private JSValue js_entry = null;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        Toolbar toolbar = (Toolbar) findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);

        FloatingActionButton fab = (FloatingActionButton) findViewById(R.id.fab);
        fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Snackbar.make(view, "Replace with your own action", Snackbar.LENGTH_LONG)
                        .setAction("Action", null).show();
            }
        });

        System.out.println("MainActivity::onCreate2");
        SeekBar sb = (SeekBar) findViewById(R.id.seekBar);
        sb.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                System.out.println("[seekbar1] progress: " + progress + ", fromUser: " + fromUser);
            }
            public void onStartTrackingTouch(SeekBar seekBar) {}
            public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        sb = (SeekBar) findViewById(R.id.seekBar2);
        sb.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                System.out.println("[seekbar2] progress: " + progress + ", fromUser: " + fromUser);
            }

            public void onStartTrackingTouch(SeekBar seekBar) {
            }

            public void onStopTrackingTouch(SeekBar seekBar) {
            }
        });

        String jscw = "";
        try {
            InputStream is = getAssets().open("cb1_engine.jscw.js");
            jscw = IOUtils.toString(is);
            IOUtils.closeQuietly(is);
        }
        catch (Exception ex) {
            ex.printStackTrace();
        }
        System.out.println("jscw bytes = " + jscw.length());

        UnderscoreObject _ = new UnderscoreObject(js_context);
        js_context.property("_", _);
        js_context.evaluateScript("function LOGGER(text) { _.dbg(text); }");
        js_context.evaluateScript("function INVOKE(name_and_args) { _.invoke(name_and_args); }");
        js_context.setExceptionHandler(new JSContext.IJSExceptionHandler() {
            @Override
            public void handle(JSException exception) {
                System.out.println("js-core throws exception: " + exception.toString());
            }
        });
        js_context.evaluateScript(jscw);
        js_entry = js_context.property("entry");

        JSValue[] args = {new JSValue(js_context, "init\t[{ \"ble\": \"la_best_007\", \"flushType\": \"by_demand\", \"uuencoded\": true }]")};
        JSValue result = js_entry.toObject().callAsFunction(null, args);
        System.out.println("init() ret: " + result.toString());

        Button btn = (Button) findViewById(R.id.button);
        btn.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                System.out.println("button is clicked!!");
                js_context.evaluateScript("LOGGER('aabbcc');");
            }
        });
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_main, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();

        //noinspection SimplifiableIfStatement
        if (id == R.id.action_settings) {
            return true;
        }

        return super.onOptionsItemSelected(item);
    }
}

interface Underscore {
    public void dbg(String line);
    public void invoke(String name_and_args);
}

class UnderscoreObject extends JSObject implements Underscore {

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