ERL=erl
APP_NAME=erlmedia
MNESIA_DATA=mnesia-data
NODE_NAME=$(APP_NAME)
VSN=0.1

all:
	( $(ERL) -make )

doc:	
	$(ERL) -pa `pwd`/ebin \
	-noshell \
	-run edoc_run application  "'$(APP_NAME)'" '"."' '[{def,{vsn,"$(VSN)"}}]'

clean:
	rm -fv ebin/*.beam
	rm -fv erl_crash.dump

clean-doc:
	rm -fv doc/*.html
	rm -fv doc/edoc-info
	rm -fv doc/*.css

run:
	$(ERL) -pa `pwd`/ebin \
	-boot start_sasl \
	-s $(APP_NAME) \
	-mnesia dir "\"${MNESIA_DATA}\"" \
	-sname $(NODE_NAME)