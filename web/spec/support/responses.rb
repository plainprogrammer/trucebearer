# Request-spec helpers for reading cookies and for comparing two responses (spec 021, ACs 5.x).
module ResponseHelpers
  def cookie_lines(response) = Array(response.headers["Set-Cookie"]).flat_map { |header| header.to_s.split("\n") }

  def cookie_line(response, name) = cookie_lines(response).find { |line| line.start_with?("#{name}=") }

  # What the stranger ACs compare: status, body, three headers, and the host_, seat_ and step_in_ cookie lines. The game id in a
  # cookie name is replaced by ID, and the session cookie is left out (its value differs on every response).
  def comparable(response, id)
    cookies = cookie_lines(response).grep(/\A(?:host|seat|step_in)_/).map { |line| line.sub(id, "ID").sub(/=[^;]*/, "=VALUE") }.sort
    headers = %w[Content-Type Cache-Control Referrer-Policy].map { |name| response.headers[name] }
    [ response.status, response.body.gsub(/\s+/, " "), headers, cookies ]
  end
end

RSpec.configure { |config| config.include ResponseHelpers, type: :request }
