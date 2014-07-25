[
	'rubygems',
	'open-uri',
	'nokogiri',
	'sequel',
	'csv'
].each{|g|
	require g
}

DB = Sequel.sqlite('../datafiles/daily_court_data.db')
# DB = Sequel.sqlite('daily_court_data.db')

DB.create_table? :defendants_broad do 
	primary_key :row_id
	String :case_num, :unique=>true
	String :defendant
	String :recent_event
	Integer :num_matches
	String :search_result_url
	Date :scan_date
end
defendants_broad = DB[:defendants_broad]

DB.create_table? :defendants_narrow do 
	primary_key :row_id
	String :case_num, :unique=>true
	String :defendant
	String :recent_event
	Integer :num_matches
	String :search_result_url
	Date :scan_date
end
defendants_narrow = DB[:defendants_narrow]

DB.create_table? :charges do 
	primary_key :row_id
	String :charge
	String :case_num
	String :scan_date
end
charges = DB[:charges]

today_date = (Time.now).strftime("%Y-%m-%d")

case_num = nil

	CSV.read("../datafiles/Court Calendar.csv")[4..-1].map{|row|
	# CSV.read("Court Calendar.csv")[4..-1].map{|row|
		if(row[4]!=nil)
			case_num = row[5]

			name_arr = row[4].split(',')
			first_name = name_arr[1].split(' ')[0]
			middle_name = name_arr[1].split(' ')[1] === nil ? '' : name_arr[1].split(' ')[1]
			last_name = name_arr[0]
			first_last = first_name+' '+last_name

			recent_event = row[18]

			url_broad = 'http://nl.newsbank.com/nl-search/we/Archives?p_product=PBPB&p_theme=pbpb&p_action=search&p_maxdocs=200&s_hidethis=no&p_field_label-0=Author&p_field_label-1=title&p_bool_label-1=AND&s_dispstring=%22'+first_name+'%20'+last_name+'%22%20AND%20date%2801/01/1989%20to%2012/31/2014%29&p_field_date-0=YMD_date&p_params_date-0=date:B,E&p_text_date-0=01/01/1989%20to%2012/31/2014%29&p_field_advanced-0=&p_text_advanced-0=%28%22'+first_name+'%20'+last_name+'%22%29&xcal_numdocs=40&p_perpage=20&p_sort=YMD_date:D&xcal_useweights=no'
			url_narrow = 'http://nl.newsbank.com/nl-search/we/Archives?p_product=PBPB&p_theme=pbpb&p_action=search&p_maxdocs=200&s_hidethis=no&p_field_label-0=Author&p_field_label-1=title&p_bool_label-1=AND&s_dispstring=%22'+first_name+'%20'+last_name+'%22%20AND%20%28jail%20OR%20police%20OR%20sheriff%20OR%20bail%29%20AND%20date%28all%29&p_field_advanced-0=&p_text_advanced-0=%22'+first_name+'%20'+last_name+'%22%20AND%20%28jail%20OR%20police%20OR%20sheriff%20OR%20bail%29&xcal_numdocs=40&p_perpage=20&p_sort=YMD_date:D&xcal_useweights=no'

			tbl_hsh = {
				defendants_broad => url_broad,
				defendants_narrow => url_narrow
			}

			tbl_hsh.each_pair{|tbl, url|
				begin
					page = Nokogiri::HTML(open(url))
				rescue Exception => e
					p "ERROR: #{e}"
					next
				end
				
				p = page.css('p[style="font-size:0.917em"]')[1] # The tag which has the number of results
				num_matches = p.text.strip.scan(/\d{1,}/)[1].to_i

				match_arr = [case_num, first_last, recent_event, num_matches, url]
				
				# if(num_matches > 0)
					begin
						tbl.insert(
							:case_num => case_num,
							:defendant => first_last,
							:recent_event => recent_event,
							:num_matches => num_matches,
							:search_result_url => url,
							:scan_date =>  today_date
						)

						# f.puts(match_arr.to_csv)
						p match_arr				
					rescue Exception => e
						p "ERROR: #{e}"
						
						tbl.where(
							"defendant = ?",
							first_last
						).update(
							:defendant => first_last,
							:num_matches => num_matches,
							:search_result_url => url,
							:scan_date =>  today_date
						)

						p match_arr
					end
				# end # DONE: if(num_matches > 0)
			} # DONE: [url_broad, url_narrow].each


		else
			if( row[27]!=nil )
				charge_arr = [ case_num, row[27], today_date ]

				charges.insert(
					:charge => row[27],
					:case_num => case_num,
					:scan_date => today_date
				)

				p charge_arr
			end
		end # DONE: if(row[4]!=nil)
	}

	headers = [
		"Case Number",
		"Scanned date",
		"Recent event",
		"Defendant",
		"Charge",
		"Match count (broad)",
		"Match count (narrow)",
		"Search results URL (narrow)"
	]


	File.open("../datafiles/defendants_"+today_date+".csv", "w"){|f|
		f.puts(headers.to_csv)
		p headers
		DB[
			"SELECT 
				t1.case_num,
				STRFTIME('%Y-%m-%d',t1.scan_date),
				t1.recent_event,
				t1.defendant,
				t3.charge,
				t1.num_matches,
				t2.num_matches,
				t2.search_result_url
			FROM (
				SELECT *
				FROM defendants_broad
				WHERE scan_date = \"#{today_date}\"
			) AS t1
			INNER JOIN (
				SELECT *
				FROM defendants_narrow
				WHERE scan_date = \"#{today_date}\"
			) AS t2
			ON t1.case_num = t2.case_num
			INNER JOIN (
				SELECT *
				FROM charges
				WHERE scan_date = \"#{today_date}\"
			) AS t3 
			ON t1.case_num = t3.case_num
			ORDER BY 
				t2.num_matches DESC,
				t2.defendant ASC
			;"
		].each{|r|
			row = r.map{|h| h[1]} # `r` is a hash, and `.map` converts each key=>value pair to an array. We get the second item in each of those converted arrays. This gives us an array with only the values
			f.puts(row.to_csv)
			p row
		}
	}

# }



