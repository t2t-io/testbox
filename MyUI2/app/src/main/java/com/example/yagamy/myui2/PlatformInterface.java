package com.example.yagamy.myui2;

/**
 * The platform interface for one CB1 engine.
 *
 * Created by yagamy on 2/14/16.
 */
public interface PlatformInterface {

    /**
     * Send the 20 bytes to CB1 via BLE write characteristic.
     *
     * @param bytes
     * @throws Exception
     */
    public void bleWriteCharacteristic(MyEngine engine, byte[] bytes);


    /**
     * Handling the property (metadata) of CB1 retrieved from BLE packet.
     *
     * @param engine the instance of CB1 engine.
     * @param name name of the property
     * @param value value of the property
     * @throws Exception
     */
    public void onSystemInfo(MyEngine engine, String name, String value);


    /**
     * Verbose messages from the engine.
     *
     * @param engine the instance of CB1 engine.
     * @param message the verbose message to output.
     */
    public void debug(MyEngine engine, String message);
}
