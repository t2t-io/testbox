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
import org.apache.commons.io.IOUtils;
import java.io.InputStream;

public class MainActivity extends AppCompatActivity {

    private MyEngine engine;

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
                engine.test(progress);
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
            System.out.println("jscw = " + jscw.length() + " bytes");
            engine = new MyEngine(jscw, MyEngine.BLUETOOTH_LA_BEST_007, MyEngine.CONSTANT_FLUSH_TYPE_BY_DEMAND, true);
        }
        catch (Exception ex) {
            ex.printStackTrace();
        }

        Button btn = (Button) findViewById(R.id.button);
        btn.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                System.out.println("button is clicked!!");
                engine.testFlush();
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

