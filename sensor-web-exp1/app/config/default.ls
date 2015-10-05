  web:
    host: '0.0.0.0'
    port: 11070
    api: 1
    express_partial_response: no
    express_method_overrid: no
    express_multer: no
    auth:
      password: 'abc'


  \uart-board :
    verbose: yes
    communicators: [
      * name: \sensorboard
        url: \tcp://127.0.0.1:7005/
        bearer: \ttyO5
        parser: \dhvac-sensorboard-v1
        config:
          aa: \bb
          cc: \dd
    ]


  \storage :
    data_sync: yes


  \storage-logger :
    enabled: no


  \storage-cmd :
    verbose: yes


  \script-runner-simple :
    scripts: [
      * name: \system
        command: '{{WORKDIR}}/scripts/stats'
        args: <[cpu apps_x]>
        cwd: '{{WORKDIR}}'
        env:
          OUTPUT_SENSORWEB: false
          WAIT_TIME: 1

      * name: \disk
        command: '{{WORKDIR}}/scripts/stats'
        args: <[disk]>
        cwd: '{{WORKDIR}}'
        env:
          OUTPUT_SENSORWEB: false
          WAIT_TIME: 60

      * name: \ram
        command: '{{WORKDIR}}/scripts/stats'
        args: <[ram]>
        cwd: '{{WORKDIR}}'
        env:
          OUTPUT_SENSORWEB: false
          WAIT_TIME: 10
    ]
