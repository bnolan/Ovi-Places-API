module Ovi
  
class Location
  attr_accessor :hash
  
  def initialize(hsh)
    @hash = hsh
  end
  
  def to_json
    @hash.to_json
  end
  
  def to_params
    params = []
    
    @hash.to_a.each do |pair|
      key, value = pair
      
      if value.kind_of? Hash
        value.to_a.each do |pair|
          params << "#{key}.#{pair.first}=#{CGI::escape pair.last.to_s}"
        end
      else
        params << "#{key}=#{CGI::escape value.to_s}"
      end
    end
    
    params.join("&")
  end
  
  def self.from_place(place)
    self.new({
      :name => place.name,
      :latitude => place.latitude,
      :longitude => place.longitude,
      :iconId => 2,
      :placeId => nil,
      :title => place.name,
      :contact => {:type => "contact", :web => "http://apps.facebook.com/weheartplaces/places/#{place.id}", :phone => place.phone_number},
      :type => "location",
      :description => place.description,
      :address => {:type => "address", :city => place.city.name, :country => place.country.name, :street => place.address}
    })
    
  end
end

class Sync
  require "net/http"
  require "net/https"
  require "mechanize"
  
  USERAGENT = 'User-Agent: Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1.6) Gecko/20091201 Firefox/3.5.6'

  def initialize(login, pass)
    a = WWW::Mechanize.new { |agent|
      agent.user_agent_alias = 'Mac Safari'
    }
    
    a.log = Logger.new('./site.log')
      
    a.post("https://account.nokia.com/fed/engine/forward.jsp?doneURL=&refID=&providerid=https%3A%2F%2Fmaps.ovi.com%2FSAML&forceauthn=true&initiatesso=1&sassoDynaMode=idp", {
      :username => login,
      :password => pass
    })

    @cookie = a.cookies.select{|c|c.domain.match(/maps.ovi.com/)}.collect{|c|[c.name,CGI::escape(c.value)].join("=")}.join("; ")
  end
  
  def sync(user)
    user.favourites.reject(&:ovi_id).each do |f|
      result = put_location(Ovi::Location.from_place(f.place))
      f.update_attributes! :ovi_id => result['location']['id']
    end
  end
  
  def cookie
    @cookie
  end
  
  def get_list
    request("http://maps.ovi.com/services/syncshare/favourite/list?sortField=date&types=route,location&limit=500&page=0&order=1&lat=0&long=0")
  end
  
  def get_size
    request("/services/syncshare/favourite/size")
  end
  
  def put_location(location)
    request("/services/syncshare/location/save", location.to_params)
  end
  
  def request(path, data = "")
    http = Net::HTTP.new("maps.ovi.com", 80)
    
    headers = {
      'Cookie' => cookie,
      'Referer' => 'http://maps.ovi.com/',
      'User-Agent' => USERAGENT,
      'Host' => 'maps.ovi.com',
      'Accept' => 'application/json, text/javascript, */*',
      'Content-Type' => 'application/x-www-form-urlencoded'
    }

    begin
      resp = http.post(path, data, headers)
    rescue EOFError
      puts "Unable to read maps.ovi.com..."
    end
    
    ActiveSupport::JSON.decode(resp.body)
  end
  
  
  # http://maps.ovi.com/services/syncshare/favourite/size
  # {"result":"1","size":2}

  # http://maps.ovi.com/services/syncshare/favourite/list?sortField=date&types=route,location&limit=50&page=0&order=1&lat=0&long=0  
  # {"result":"1","favourites":[{"type":"location","id":23557601,"name":"Victoria St, 180, Wellington","title":"Victoria St, 180, Wellington","description":null,"localId":null,"iconId":2,"timestamp":1262668544000,"longitude":174.773544073105,"latitude":-41.2931645454115,"address":{"type":"address","name":"address","title":"address","description":null,"country":null,"state":null,"county":null,"city":"Wellington","district":null,"postalCode":null,"street":"Victoria St","streetNumber":"181"},"contact":{"type":"contact","email":null,"fax":null,"mobile":null,"phone":null,"sip":null,"web":null},"placeId":null}]}
  
  # http://maps.ovi.com/services/syncshare/location/save
  # {"result":"1","location":{"type":"location","id":25226353,"name":"Some place","title":"Some place","description":null,"localId":null,"iconId":2,"timestamp":1263250495000,"longitude":174.776113629341,"latitude":-41.2905325645714,"address":{"type":"address","name":"address","title":"address","description":null,"country":"NZL","state":null,"county":null,"city":"Wellington","district":null,"postalCode":null,"street":"Manners St","streetNumber":"50"},"contact":{"type":"contact","email":null,"fax":null,"mobile":null,"phone":null,"sip":null,"web":null},"placeId":null}}
  # {"result":"1","location":{"address":{"street":"9 Riddiford Street, Newtown,","type":"address","country":"NZL","city":"Wellington"},"type":"location","description":"A nice quiet upstairs cafe in a chilled out part of town. Big feeds for not too much money. Usually has a newspaper and some free tables on the weekend. Great place to for a brunch.","contact":{"type":"contact","web":"http://apps.facebook.com/weheartplaces/places/935148510","phone":"+64 4 389 4828"},"name":"Ballroom cafe","title":"Ballroom cafe","latitude":-41.3081016540527,"longitude":174.77799987793,"iconId":2}}



end

end

# {
#   "timestamp"=>1263252127000, 
#   "name"=>"Mortimer Ter, 72, Wellington, NZL", 
#   "latitude"=>-41.2994760300282, 
#   "iconId"=>2, 
#   "title"=>"Mortimer Ter, 72, Wellington, NZL", 
#   "contact"=>{"sip"=>nil, "type"=>"contact", "mobile"=>nil, "phone"=>nil, "fax"=>nil, "web"=>nil, "email"=>nil}, 
#   "type"=>"location", 
#   "id"=>25230369, 
#   "placeId"=>nil, 
#   "localId"=>nil, 
#   "description"=>nil, 
#   "longitude"=>174.762954711914, 
#   "address"=>{
#     "city"=>"Wellington", 
#     "name"=>"address", 
#     "title"=>"address", 
#     "district"=>nil, 
#     "county"=>nil, 
#     "country"=>"NZL", 
#     "type"=>"address", 
#     "streetNumber"=>"72", 
#     "postalCode"=>nil, 
#     "description"=>nil, 
#     "street"=>"Mortimer Ter", 
#     "state"=>nil
#   }
# }
