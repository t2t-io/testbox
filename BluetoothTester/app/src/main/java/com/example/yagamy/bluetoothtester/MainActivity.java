package com.example.yagamy.bluetoothtester;

import java.util.UUID;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.ParcelUuid;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;
import android.widget.CheckBox;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.bluetooth.le.ScanFilter;

import com.neovisionaries.bluetooth.ble.advertising.ADPayloadParser;
import com.neovisionaries.bluetooth.ble.advertising.ADStructure;
import com.neovisionaries.bluetooth.ble.advertising.LocalName;
import com.neovisionaries.bluetooth.ble.advertising.UUIDs;

import java.util.ArrayList;
import java.util.List;

import io.t2t.android.utils.Test;
import io.t2t.j2se.util.MyClass;

public class MainActivity extends AppCompatActivity {

    private TextView console;
    private Button scanButton;
    private Button clearButton;
    private CheckBox legacyCheckbox;

    private BluetoothManager bluetooth;
    private BluetoothAdapter adapter;
    private Handler handler;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        console = (TextView) findViewById(R.id.textConsole);
        scanButton = (Button) findViewById(R.id.scanButton);
        clearButton = (Button) findViewById(R.id.clearButton);
        legacyCheckbox = (CheckBox) findViewById(R.id.legacyCheckbox);

        grantBLE();

        scanButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                onScanClick();
            }
        });

        clearButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                console.setText("");
            }
        });

        consolePrintln("Build.VERSION.SDK_INT = " + Build.VERSION.SDK_INT);
        consolePrintln("hasSystemFeature(FEATURE_BLUETOOTH_LE) = " +
                getPackageManager().hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE));

        bluetooth = (BluetoothManager) getSystemService(Context.BLUETOOTH_SERVICE);
        adapter = bluetooth.getAdapter();
        handler = new Handler();

        Test test = new Test("AAA");
        consolePrintln(test.getMyName());

        MyClass aa = new MyClass("bb");
        consolePrintln(aa.getClassNameAdv());
    }

    private void grantBLE() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return;

        final Activity activity = this;
        if (activity.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            return;
        }

        final AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setTitle("This app needs location access");
        builder.setMessage("Please grant location access so this app can detect beacons.");
        builder.setPositiveButton(android.R.string.ok, null);
        builder.setOnDismissListener(new DialogInterface.OnDismissListener() {
            @Override
            public void onDismiss(DialogInterface dialog) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    activity.requestPermissions(new String[]{Manifest.permission.ACCESS_COARSE_LOCATION}, 0);
                }
            }
        });
        builder.show();
    }

    private boolean scanning = false;

    private void onScanClick() {
        if (scanning) {
            scanButton.setText("Start Scan");
            scanning = false;
            scanLeDevice(scanning);
        }
        else {
            scanButton.setText("Stop Scan");
            scanning = true;
            scanLeDevice(scanning);
        }
    }

    private final static int SCAN_PERIOD = 10000;

    private void scanLeDevice(final boolean enable) {
        final boolean legacy = legacyCheckbox.isChecked();
        if (enable) {
            final BluetoothAdapter adapter = this.adapter;
            handler.postDelayed(new Runnable() {
                @Override
                public void run() {
                    if (legacy || Build.VERSION.SDK_INT < 21) {
                        adapter.stopLeScan(leScanCallback);
                    } else {
                        adapter.getBluetoothLeScanner().stopScan(scanCallback);
                    }
                    scanButton.setText("Start Scan");
                    scanning = false;
                    consolePrintln("scan finished.");
                }
            }, SCAN_PERIOD);
            if (legacy || Build.VERSION.SDK_INT < 21) {
                adapter.startLeScan(leScanCallback);
            } else {
                ScanSettings settings = new ScanSettings.Builder()
                        .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                        .build();
                ArrayList<ScanFilter> filters = new ArrayList<ScanFilter>();
                adapter.getBluetoothLeScanner().startScan(filters, settings, scanCallback);
            }
        } else {
            if (legacy || Build.VERSION.SDK_INT < 21) {
                adapter.stopLeScan(leScanCallback);
            } else {
                adapter.getBluetoothLeScanner().stopScan(scanCallback);
            }
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

    // Bluetooth Scan Callback for Android v5.X
    private ScanCallback scanCallback = new ScanCallback() {
        public void onScanResult(int callbackType, ScanResult result) {
            // [todo]
            ScanRecord record = result.getScanRecord();
            BluetoothDevice device = result.getDevice();
            String name = record.getDeviceName();
            String type = checkType(record.getServiceUuids());
            consolePrintln("LeScanner: " + name + ", " + device.getAddress() + ", " + result.getRssi() + ", " + type);
        }
        public void onBatchScanResults(List<ScanResult> results) {
            // [todo] need to handle this kind of callback!?
        }
        public void onScanFailed(int errorCode) {
            switch (errorCode) {
                case ScanCallback.SCAN_FAILED_ALREADY_STARTED:
                    // Fails to start scan as BLE scan with the same settings is already started by the app.
                    break;
                case ScanCallback.SCAN_FAILED_APPLICATION_REGISTRATION_FAILED:
                    // Fails to start scan as app cannot be registered.
                    break;
                case ScanCallback.SCAN_FAILED_FEATURE_UNSUPPORTED:
                    // Fails to start power optimized scan as this feature is not supported.
                    break;
                case ScanCallback.SCAN_FAILED_INTERNAL_ERROR:
                    // Fails to start scan due an internal error
                    break;
            }
        }
    };

    private String checkType(UUID u) {
        if (u.equals(BLE_SERVICE_OV3)) {
            return "OV3";
        } else if (u.equals(BLE_SERVICE_LA_BEST_007)) {
            return "LA_BEST_007";
        }
        else {
            return null;
        }
    }

    private String checkType(List<ParcelUuid> uuids) {
        if (uuids == null) {
            return "no-parcel-uuid(s)";
        }

        for (ParcelUuid u: uuids) {
            String type = checkType(u.getUuid());
            if (type != null) {
                return type;
            }
        }
        return "unknown";
    }

    // Bluetooth Scan Callback for Android v4.4.X
    private BluetoothAdapter.LeScanCallback leScanCallback = new BluetoothAdapter.LeScanCallback() {
        public void onLeScan(final BluetoothDevice device, int rssi, byte[] scanRecord) {
            // [todo]
            String name = device.getName();
            String localName = null;
            String type = null;

            List<ADStructure> structures = ADPayloadParser.getInstance().parse(scanRecord);
            for (ADStructure s : structures) {
                if (s instanceof UUIDs) {
                    UUID[] uuids = ((UUIDs) s).getUUIDs();
                    for (UUID u : uuids) {
                        type = checkType(u);
                    }
                }
                else if (s instanceof LocalName) {
                /* Not use this condition, maybe it will be use someday. */
                    localName = ((LocalName) s).getLocalName();
                    continue;
                }
            }
            consolePrintln("Legacy: " + name + ", " + device.getAddress() + ", " + rssi + ", " + type);
        }
    };

    private final UUID BLE_SERVICE_OV3 = UUID.fromString("00001a20-0000-1000-8000-00805f9b34fb");
    private final UUID BLE_SERVICE_LA_BEST_007 = UUID.fromString("0000F680-0000-1000-8000-00805f9b34fb");


}