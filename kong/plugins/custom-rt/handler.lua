local kong = kong


local DEFAULT_RESPONSE = {
  [401] = "Unauthorized",
  [404] = "Not found",
  [405] = "Method not allowed",
  [500] = "An unexpected error occurred",
  [502] = "Bad Gateway",
  [503] = "Service unavailable",
}


local RequestTerminationHandler = {}


RequestTerminationHandler.PRIORITY = 2
RequestTerminationHandler.VERSION = "2.1.0"


function RequestTerminationHandler:access(conf)
  local status  = conf.status_code
  local content = conf.body
  local req_headers, req_query

  if conf.trigger or conf.echo or conf.avert then
    req_headers = kong.request.get_headers()
    req_query = kong.request.get_query()

    if conf.trigger and not conf.trigger_value
       and not req_headers[conf.trigger]
       and not req_query[conf.trigger] then
      return -- trigger set but not found, nothing to do
    if conf.trigger_value and conf.trigger
       and not req_headers[conf.trigger] == conf.trigger_value
       and not req_query[conf.trigger] == conf.trigger_value
      return -- trigger_value set but not found, nothing to do
    end

    if conf.avert and not conf.avert_value
       and req_headers[conf.avert]
       or req_query[conf.avert] then
      return -- avert set and found, nothing to do
    if conf.avert_value and conf.avert
       and req_headers[conf.avert] == conf.avert_value
       or req_query[conf.avert] == conf.avert_value
      return -- avert_value set and found, nothing to do
    end
  end

  if conf.echo then
    content = {
      message = conf.message or DEFAULT_RESPONSE[status],
      kong = {
        node_id = kong.node.get_id(),
        worker_pid = ngx.worker.pid(),
        hostname = kong.node.get_hostname(),
      },
      request = {
        scheme = kong.request.get_scheme(),
        host = kong.request.get_host(),
        port = kong.request.get_port(),
        headers = req_headers,
        query = req_query,
        body = kong.request.get_body(),
        raw_body = kong.request.get_raw_body(),
        method = kong.request.get_method(),
        path = kong.request.get_path(),
      },
      matched_route = kong.router.get_route(),
      matched_service = kong.router.get_service(),
    }

    return kong.response.exit(status, content)
  end

  if content then
    local headers = {
      ["Content-Type"] = conf.content_type
    }

    return kong.response.exit(status, content, headers)
  end

  local message = conf.message or DEFAULT_RESPONSE[status]
  return kong.response.exit(status, message and { message = message } or nil)
end


return RequestTerminationHandler
