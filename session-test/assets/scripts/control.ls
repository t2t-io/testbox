
class AgentPanel
  (@data, @index) ->
    return

  render: ->
    {ttt, id, runtime, iface, os, uid, cc, uptime, geoip} = @data
    {ipv4, mac, software_version, socketio_version, protocol_version} = cc
    {profile, profile_version, sn} = ttt
    {node_version, node_arch, node_platform}  = runtime
    {ip} = geoip
    geolocation = geoip.data['ipstack.com']
    sio = ""
    sio = ", sio-#{socketio_version}" if socketio_version? and socketio_version isnt "unknown"
    vinfo = profile_version
    vinfo = "#{profile_version} (<small>#{software_version}</small>)" if software_version? and software_version isnt "unknown"
    ninfo = "#{ipv4}<br>#{ip}"
    uptime = humanizeDuration uptime, largest: 3, round: true, units: <[y mo w d h m s]>
    {hostname} = os
    cid = "collapse_#{id}"
    hid = "heading_#{id}"
    pid = "accordion_#{profile}"
    sn = hostname unless sn? and sn isnt ""
    return """
      <div class="panel panel-default">
        <div class="panel-heading" role="tab" id="#{hid}">
          <br/>
          <h5 class="panel-title">#{id} (#{sn})</h5>
        </div>
        <div class="panel-body">
          <table class="table table-hover">
            <tbody>
              <tr><td>system</td><td>
                <small>
                  <p>hostname: <strong>#{hostname}</strong></p>
                  <p>private: <strong>#{ipv4}</strong></p>
                  <p>public: <strong>#{ip}</strong></p>
                  <p>uptime: #{uptime}</p>
                </small>
                </td>
                <td><small>
                  <p>#{node_platform}-#{node_arch}</p>
                  <p>#{mac}</p>
                  <p>#{geolocation.location.country_flag_emoji} #{geolocation.region_name}, #{geolocation.country_name}, #{geolocation.continent_name} (<a href="https://maps.google.com?z=14&ll=#{geolocation.latitude},#{geolocation.longitude}">map</a>)</p>
                  <p>#{geolocation.time_zone.id} (<strong>#{geolocation.time_zone.code}</strong>)</p>
                </small></td>
                </tr>
              <tr><td>configurations</td><td>
                <small>
                  <p>profile: <strong>#{profile_version}</strong></p>
                  <p>app: <strong>#{software_version}</strong></p>
                  <p>nodejs: <strong>#{node_version}</strong></p>
                  <p>socket.io: #{socketio_version}</p>
                </small>
                </td>
                <td><small>
                  <p>#{protocol_version}</p>
                </small></td>
                </tr>
              <tr><td>actions</td><td>
                  <button class="btn btn-info btn-xs" id="agent_button_console_#{uid}">
                    <span class="glyphicon glyphicon-log-in" aria-hidden="true"></span>
                    Console
                  </button>
                  </td>
                  <td></td>
                </tr>
            </tbody>
          </table>
        </div>
      </div>
    """


class AgentsContainer
  (@agentPanels, @category) ->
    return

  render: ->
    {agentPanels, category} = @
    pid = "accordion_#{category}"
    panels = [ a.render! for id, a of agentPanels ]
    return """
        #{panels.join '\n'}
    """


class CategoryPanel
  (@category, @agents, @active) ->
    @agentPanels = [ (new AgentPanel a, i) for let a, i in agents ]
    @agentContainer = new AgentsContainer @agentPanels, category
    @tabName = "c-#{category.split '.' .join '-'}"
    return

  renderTab: ->
    {agentContainer, active, category, tabName} = @
    active-class = if active then "active" else ""
    activeSelected = if active then "true" else "false"
    return """
      <li class="nav-item">
        <a class="nav-link #{active-class}" id="#{tabName}-tab" data-toggle="tab" href="\##{tabName}" role="tab" aria-controls="#{tabName}" aria-selected="#{activeSelected}">#{category}</a>
      </li>
    """

  renderPanel: ->
    {agentContainer, active, category, tabName} = @
    active-class = if active then "show active" else ""
    return """
      <div class="tab-pane fade #{active-class}" id="#{tabName}" role="tabpanel" aria-labelledby="#{tabName}-tab">
        #{agentContainer.render!}
      </div>
    """


button-onclick-currying = (uid, action, dummy) -->
  return window.contextManager.performAction uid, action


class AgentDashboard
  (@context) ->
    categoryPanels = @categoryPanels = []
    {categories} = context
    firstActive = yes
    for category, agents of categories
      console.log "#{name} categoryPanels: #{firstActive}"
      cp = new CategoryPanel category, agents, firstActive
      categoryPanels.push cp
      firstActive := no if firstActive
    return

  render: ->
    {categoryPanels} = @
    tabs = [ pp.renderTab! for pp in categoryPanels ]
    tab-head = """
      <ul class="nav nav-tabs" role="tablist">
        #{tabs.join '\n'}
      </ul>
    """
    panels = [ pp.renderPanel! for pp in categoryPanels ]
    tab-body = """
      <div class="tab-content" id="nav-tabContent">
        #{panels.join '\n'}
      </div>
    """
    return tab-head + tab-body

  show: ->
    text = @.render!
    ads = $ "\#agent-dashboard"
    ad = ads[0]
    ad.innerHTML = text
    buttons = $ "[id^=agent_button]"
    for b in buttons
      id = b.id
      tokens = id.split '_'
      action = tokens[2]
      uid = parseInt tokens[3]
      f = button-onclick-currying uid, action
      b.onclick = f


class ContextManager
  (@opts) ->
    @categories = {}
    return

  processData: (@agents) ->
    {opts} = self = @
    self.categories = {}
    for let a, i in agents
      {system, cc, uptime, geoip} = a
      {ttt, id, runtime, iface} = system
      {ip} = geoip
      if iface? and iface.iface?
        {ipv4, mac} = iface.iface
      else
        ipv4 = "unknown"
        mac = "unknown"
      console.log "uptime: #{uptime}, cc => #{JSON.stringify cc}"
      console.log "system => #{JSON.stringify system}"
      xs = {} <<< system
      xs.cc = cc
      xs.uid = i
      xs.uptime = uptime
      xs.geoip = geoip
      key = ip
      {categories} = self
      categories[key] = [] unless categories[key]
      categories[key].push xs

  performAction: (uid, action) ->
    a = @agents[uid]
    # console.log "perform-action: #{action} => #{JSON.stringify a}"
    {id, system} = a
    {hostname} = system.os
    xs = $ '\#agent-dashboard'
    xs[0].hidden = yes if xs.length > 0
    xs = $ '\#term-container'
    xs[0].hidden = no
    xs = $ '\#terminal-title'
    xs[0].innerHTML = "#{id}"


<- $
{pathname, host, protocol} = window.location
url = "#{protocol}//#{host}/control"
s = io.connect url
s.on \unauthorized, -> window.location = '/views/login'
s.on \connect, ->
  console.log "websocket is connected!!"
  s.emit \fn-get-agent-list, {sorted: no}, (results) ->
    {err, data} = results
    return console.log err if err?
    console.log "data => #{JSON.stringify data}"
    for let a, i in data
      {id, runtime, os, mac_address} = a.system
      {node_version, node_arch, node_platform} = runtime
      {hostname} = os
      {protocol_version, software_version, instance_id} = a.cc
      {ip} = a.geoip
      console.log "agents[#{i}]/#{id} => #{hostname}, #{mac_address}"
      console.log "agents[#{i}]/#{id} => #{node_version}, #{node_arch}, #{node_platform}"
      console.log "agents[#{i}]/#{id} => #{protocol_version}, #{software_version}, #{instance_id}"
      console.log "agents[#{i}]/#{id} => #{ip}"
    contextManager = window.contextManager = new ContextManager {}
    contextManager.processData data
    agentDashboard = window.agentDashboard = new AgentDashboard contextManager
    agentDashboard.show!

  return
