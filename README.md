# YorkBinCollection

This is an interface to the City of York website, scraping the calendar page
for refuse collection (or using its JSON API where possible).

## Installation

```
gem install york-bin-collection
```

## Usage

```ruby
require 'york-bin-collection'

# Get the unique ID (UPRN) for some property in a postcode
uprn = YorkBinCollection.get_uprns_for_postcode("YO10 1AB").sample

# Get the collection schedules
dates = YorkBinCollection.get_collection_dates(uprn)
dates.recycling # => [Date, Date, ...]
dates.household # => [Date, Date, ...]
dates.garden # => [Date, Date, ...]
```