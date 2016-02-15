package com.example.yagamy.myui2;

import android.Manifest;
import android.app.AlertDialog;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.bluetooth.le.ScanFilter;
import android.content.Context;
import android.content.DialogInterface;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.support.design.widget.FloatingActionButton;
import android.support.design.widget.Snackbar;
import android.support.v7.app.AppCompatActivity;
import android.support.v7.widget.Toolbar;
import android.view.View;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.CheckBox;
import android.widget.SeekBar;
import android.widget.Button;
import android.widget.TextView;

import org.apache.commons.io.IOUtils;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

public class MainActivity extends AppCompatActivity implements PlatformInterface {

    private MyEngine engine;

    private static final long SCAN_PERIOD = 4000;
    private static final String TARGET_MAC_ADDRESS = "20:15:08:21:10:29";
    private BluetoothAdapter adapter;
    private BluetoothLeScanner scanner;
    private BluetoothDevice device;
    private BluetoothGatt gatt;
    private BluetoothGattCharacteristic characteristic;
    private Handler handler;

    private TextView console;
    private Button connectButton;

    private int counter = 0;

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
                engine.testMotor1(progress);
                counter++;
                if (counter >= 5) {
                    engine.testFlush();
                }
            }
            public void onStartTrackingTouch(SeekBar seekBar) {}
            public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        console = (TextView) findViewById(R.id.textConsole);

        sb = (SeekBar) findViewById(R.id.seekBar2);
        sb.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                System.out.println("[seekbar2] progress: " + progress + ", fromUser: " + fromUser);
                engine.testMotor2(progress);
                counter++;
                if (counter >= 5) {
                    engine.testFlush();
                }
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
            engine = new MyEngine(jscw, MyEngine.BLUETOOTH_LA_BEST_007, MyEngine.CONSTANT_FLUSH_TYPE_BY_DEMAND, true, this);
        }
        catch (Exception ex) {
            ex.printStackTrace();
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // Android M Permission check 
            if (this.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                final AlertDialog.Builder builder = new AlertDialog.Builder(this);
                builder.setTitle("This app needs location access");
                builder.setMessage("Please grant location access so this app can detect beacons.");
                builder.setPositiveButton(android.R.string.ok, null);
                builder.setOnDismissListener(new DialogInterface.OnDismissListener() {
                    @Override
                    public void onDismiss(DialogInterface dialog) {
                        requestPermissions(new String[]{Manifest.permission.ACCESS_COARSE_LOCATION}, 0);
                    }
                });
                builder.show();
            }
        }

        final BluetoothManager bluetoothManager = (BluetoothManager) getSystemService(Context.BLUETOOTH_SERVICE);
        adapter = bluetoothManager.getAdapter();
        handler = new Handler();
        scanner = adapter.getBluetoothLeScanner();

        Button btn = null;
        btn = (Button) findViewById(R.id.discoverButton);
        btn.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                System.out.println("discover button is clicked!!");
                scanLeDevice(true);
            }
        });

        connectButton = (Button) findViewById(R.id.connectButton);
        connectButton.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                System.out.println("connect button is clicked!!");
                console.append("connecting to " + device.getAddress() + " ...\n");
                connectButton.setVisibility(View.INVISIBLE);
                connectLeDevice();
            }
        });

    }

    private void connectLeDevice() {
        if (device != null) {
            gatt = device.connectGatt(this, false, gattCallback);
        }
    }

    private void scanLeDevice(final boolean enable) {
        if (enable) {
            handler.postDelayed(new Runnable() {
                @Override
                public void run() {
                    scanner.stopScan(scanCallback);
                    console.append("bluetooth scanning is stopped.\n");
                    if (device != null) {
                        connectButton.setVisibility(View.VISIBLE);
                    }
                }
            }, SCAN_PERIOD);

            console.setText("");
            connectButton.setVisibility(View.INVISIBLE);
            device = null;
            characteristic = null;

            ScanSettings settings = new ScanSettings.Builder()
                    .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                    .build();
            List<ScanFilter> filters = new ArrayList<ScanFilter>();
            scanner.startScan(filters, settings, scanCallback);
        } else {
            scanner.stopScan(scanCallback);
        }
    }

    private void consolePrintln(final String message) {
        System.out.println(message);
        this.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                console.append(message);
                console.append("\n");
            }
        });
    }

    private void handleDiscoveredGatt(BluetoothGatt gatt, int status) {
        List<BluetoothGattService> services = gatt.getServices();
        for (BluetoothGattService s: services) {
            List<BluetoothGattCharacteristic> chars = s.getCharacteristics();
            consolePrintln(s.getUuid().toString() + " has " + chars.size() + " characteristics");
            for (int i = 0; i < chars.size(); i++) {
                BluetoothGattCharacteristic c = chars.get(i);
                // consolePrintln("  chars[" + i + "] => " + c.getUuid().toString());
                final String uuid = "0000f681-0000-1000-8000-00805f9b34fb";
                if (c.getUuid().toString().equals(uuid)) {
                    consolePrintln("found characteristic to write!! => " + uuid);
                    characteristic = c;
                    final CheckBox cb = (CheckBox) this.findViewById(R.id.readyCheckbox);
                    final SeekBar seekbar1 = (SeekBar) this.findViewById(R.id.seekBar);
                    final SeekBar seekbar2 = (SeekBar) this.findViewById(R.id.seekBar2);
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            cb.setChecked(true);
                            seekbar1.setVisibility(View.VISIBLE);
                            seekbar2.setVisibility(View.VISIBLE);
                        }
                    });
                }
            }
        }
    }

    private BluetoothGattCallback gattCallback = new BluetoothGattCallback() {
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
            switch (newState) {
                case BluetoothProfile.STATE_CONNECTED:
                    consolePrintln(device.getAddress() + ": STATE_CONNECTED, and start service discovering ...");
                    gatt.discoverServices();
                    connectButton.setVisibility(View.INVISIBLE);
                    break;
                case BluetoothProfile.STATE_DISCONNECTED:
                    consolePrintln(device.getAddress() + ": STATE_DISCONNECTED");
                    connectButton.setVisibility(View.VISIBLE);
                    break;
                default:
                    consolePrintln(device.getAddress() + ": STATE_OTHER");
            }
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {
            handleDiscoveredGatt(gatt, status);
        }

        @Override
        public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
            System.out.println("onCharacteristicRead");
        }
    };

    private ScanCallback scanCallback = new ScanCallback() {
        @Override
        public void onScanResult(int callbackType, ScanResult result) {
            System.out.println("callbackType = " + callbackType);
            System.out.println("result = " + result.toString());
            BluetoothDevice d = result.getDevice();
            StringBuffer line = new StringBuffer();
            line.append(d.getAddress()).append('\t')
                    .append(d.getName()).append('\t')
                    .append('\n');
            console.append(line.toString());
            if (d.getAddress().equals(TARGET_MAC_ADDRESS)) {
                console.append("found!!\n");
                device = d;
            }
        }

        @Override
        public void onBatchScanResults(List<ScanResult> results) {
            for (ScanResult sr : results) {
                System.out.println("ScanResult - Results => " + sr.toString());
            }
        }

        @Override
        public void onScanFailed(int errorCode) {
            System.out.println("Scan Failed, Error Code: " + errorCode);
        }
    };

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

    @Override
    public void bleWriteCharacteristic(MyEngine engine, byte[] bytes) {
        for (byte b: bytes) {
            System.out.println("bleWriteCharacteristic => byte: " + b);
        }
        if (characteristic != null) {
            consolePrintln("writing character...");
            characteristic.setValue(bytes);
            gatt.writeCharacteristic(characteristic);
        }
    }

    @Override
    public void onSystemInfo(MyEngine engine, String name, String value) {
        System.out.println("onSystemInfo => " + name + ", " + value);
    }

    @Override
    public void debug(MyEngine engine, String message) {
        System.out.println("engineDebug => " + message);
    }
}

