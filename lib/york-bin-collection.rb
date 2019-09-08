require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'json'

module YorkBinCollection
  VERSION = '1.0.0'

  CALENDARS_ENDPOINT = 'https://doitonline.york.gov.uk/BinsApi/Calendars/Index'
  EXOR_ENDPOINT = 'https://doitonline.york.gov.uk/BinsApi/EXOR'

  CollectionDates = Struct.new('CollectionDates', :recycling, :household, :garden)

  ##
  # Checks if a UPRN is syntatically valid; that is, if is a string is 
  # alphanumeric. 
  # According to the Ordinance Survey, UPRNs can be alphanumeric, although I
  # have yet to find an example with alphabetic characters in.
  # @param [String] uprn The string to validate as a UPRN number.
  # @return [Boolean] True if the string is a syntatically valid UPRN, false
  #   otherwise.
  def self.valid_uprn?(uprn)
    /[A-Za-z0-9]+/ === uprn || up
  end

  ##
  # A hash of collection types, as keys in a CollectionDates object, to their
  # 'friendly' names.
  def self.collection_types
    {
      recycling: 'Recycling',
      household: 'Household waste',
      garden: 'Garden waste'
    }
  end

  ##
  # Given a valid UPRN in the City of York, returns an CollectionDates struct of
  # dates each bin will be collected. The keys are :recycling, :household and
  # :garden.
  # @param [String] uprn A valid UPRN.
  # @return [CollectionDates] The known waste collection dates.
  def self.get_collection_dates(uprn)
    raise ArgumentError, 'invalid uprn' unless valid_uprn?(uprn)
    url = CALENDARS_ENDPOINT + "?uprn=#{uprn}"
    document = Nokogiri::HTML(open(url))

    # The format of the document is:
    #   body
    #     div.container-fluid
    #       ~header~
    #       div
    #         div.col-xs-12 col-sm-3
    #           h2: December 2018
    #           div.row
    #             div: Tue 04 
    #             div: Household waste
    #           ...
    #           h2: January 2019
    #           ...
    #         div.col-xs-12 col-sm-3
    #           h2: March 2019
    #           ...
    #         ...
    
    # Let's start by getting the div which contains the columns, and flatten out
    # the structure to get rid of them
    collection_date_elements = []
    document.css('body > div.container-fluid > div > div.col-xs-12.col-sm-3').each do |col|
      collection_date_elements.push(*col.children)
    end

    collection_dates = CollectionDates.new([], [], [])
    current_heading = nil

    collection_date_elements.each do |row_or_heading|
      if row_or_heading.name == "h2"
        current_heading = row_or_heading.text
      else
        raise 'format error: didn\'t encounter heading before date' unless current_heading

        day, kind = row_or_heading.children.map(&:text)
        date = Date.parse("#{day} #{current_heading}")
        key = collection_types.rassoc(kind)&.first
        raise "unknown collection kind #{kind}" unless kind

        collection_dates.send(key) << date
      end
    end

    collection_dates
  end

  ##
  # Given a postcode, returns a hash of UPRNs in that postcode to their house
  # addresses.
  # @param [String] postcode A valid postcode, which is permitted to include
  #   a space.
  # @param [Hash] A hash of UPRNs to short addresses for the property. If the
  #   postcode is invalid, this may be blank.
  def self.get_uprns_for_postcode(postcode)
    url = "#{EXOR_ENDPOINT}/getPropertiesForPostCode?postcode=#{CGI.escape(postcode)}"
    JSON.parse(open(url).read).map do |property|
      [property['Uprn'].to_s, property['ShortAddress']]
    end.to_h
  end
end