/**
* Sentry SDK for ColdFusion 10
*
* This CFC is a slight modification of the sentry-cfml2 client by KrunchMuffin (https://github.com/KrunchMuffin/sentry-cfml2)
*
* Which is based on the fork sentry-cfml client developed
* by GiancarloGomez (https://github.com/GiancarloGomez/sentry-cfml)
*
* Which it was based off of the original raven-cfml client developed
* by jmacul2 (https://github.com/jmacul2/raven-cfml)
*
* This code has been modified to run under ColdFusion 10.
* Testing on later versions of ColdFusion and Lucee has not been done.
*
* Sentry SDK Documentation
* https://docs.sentry.io/clientdev/
*/
component displayname="sentry" output="false" accessors="true"{

	property name="environment" type="string";
	property name="levels" type="array";
	property name="logger" type="string" default="sentry-cfml2-cf10";
	property name="platform" type="string" default="cfml";
	property name="release" type="string";
	property name="privateKey";
	property name="projectID";
	property name="publicKey";
	property name="version" type="string" default="2.0.0" hint="sentry-cfml2 version";
	property name="sentryUrl" type="string" default="https://sentry.io";
	property name="sentryVersion" type="string" default="7";
	property name="serverName" type="string";
	property name="level" Type="string" default="error";
	property name="nonAppPathPatterns" Type="array";

	/**
	* @release The release version of the application.
	* @environment The environment name, such as ‘production’ or ‘staging’.
	* @DSN A DSN string to connect to Sentry's API, the values can also be passed as individual arguments
	* @publicKey The Public Key for your Sentry Account
	* @privateKey The Private Key for your Sentry Account
	* @projectID The ID Sentry Project
	* @sentryUrl The Sentry API url which defaults to https://sentry.io
	* @serverName The name of the server, defaults to cgi.server_name
	* @nonAppPathPatterns A list of regex patterns (as strings) that when matched to a stacktrace filepath, that frame will be marked as in_app=false.
	*/
	function init(
		string release,
		string environment,
		string DSN,
		string publicKey,
		string privateKey,
		numeric projectID,
		string sentryUrl,
		string serverName = cgi.server_name,
		array nonAppPathPatterns = []
	) {
		// set keys via DSN (Legacy) or keys and id
		if (structKeyExists(arguments,"DSN") && len(trim(arguments.DSN))){
			parseDSN(arguments.DSN);
		}
		else if (
			( structKeyExists(arguments,"publicKey") && len(trim(arguments.publicKey)) ) &&
			( structKeyExists(arguments,"privateKey") && len(trim(arguments.privateKey)) ) &&
			( structKeyExists(arguments,"projectID") && len(trim(arguments.projectID)) )
		) {
			setPublicKey(arguments.publicKey);
			setPrivateKey(arguments.privateKey);
			setProjectID(arguments.projectID);
		}
		else {
			throw(message = "You must pass in a valid DSN or Project Keys and ID to instantiate the Sentry CFML Client.");
		}
		// set defaults
		setLevels(["fatal","error","warning","info","debug"]);
		// set optional
		setEnvironment(structKeyExists(arguments, "environment") ? arguments.environment : "N/A");
		setRelease(structKeyExists(arguments, "release") ? arguments.release : "N/A");
		setServerName(arguments.serverName);
		// overwrite defaults
		if ( structKeyExists(arguments,"sentryUrl") && len(trim(arguments.sentryUrl)) )
			setSentryUrl(arguments.sentryUrl);

		setNonAppPathPatterns(arguments.nonAppPathPatterns);

		return this;
	}

	/**
	* Parses a valid LEGACY Sentry DSN
	* {PROTOCOL}://{PUBLIC_KEY}:{SECRET_KEY}@{HOST}/{PATH}{PROJECT_ID}
	* https://docs.sentry.io/clientdev/overview/#parsing-the-dsn
	*/
	private void function parseDSN(required string DSN) {
		var pattern = "^(?:(\w+):)?\/\/(\w+):(\w+)?@([\w\.-]+)\/(.*)";
		var result 	= reFind(pattern,arguments.DSN,1,true);
		var segments = [];

		for(var i=1; i LTE ArrayLen(result.pos); i++){
			arrayAppend(segments, mid(arguments.DSN, result.pos[i], result.len[i]));
		}

		if (arrayLen(segments) neq 6) {
			// should be 5 parts to the DSN, (we ask for 6 because refind will return the whole capture group as #1) otherwise, it's likely the new DSN or just a bad value.
			throw(message="Error parsing DSN. Make sure you are using the Legacy DSN if you intend to use the DSN option.");
		}
		// set the properties
		else {
			setSentryUrl(segments[2] & "://" & segments[5]);
			setPublicKey(segments[3]);
			setPrivateKey(segments[4]);
			setProjectID(segments[6]);
		}
	}

	/**
	* Validates that a correct level was set for a capture
	* The allowed levels are:
	* 	"fatal","error","warning","info","debug"
	*/
	private void function validateLevel(required string level) {
		if(!arrayFind(getLevels(), arguments.level)) {
			// if it's not one of the above, just set error as default. no need to throw hard error.
			setLevel("error");
		} else {
			setLevel(arguments.level);
		}
	}

	/**
	* Capture a message
	* https://docs.sentry.io/clientdev/interfaces/message/
	*
	* @message the raw message string ( max length of 1000 characters )
	* @level The level to log
	* @path The path to the script currently executing
	* @useThread Option to send post to Sentry in its own thread
	* @userInfo Optional Struct that gets passed to the Sentry User Interface
	*/
	public any function captureMessage(
		required string message,
		string level = "info",
		string path = "",
		boolean useThread = false,
		struct userInfo = {}
	) {
		var sentryMessage = {};

		validateLevel(arguments.level);

		if (len(trim(arguments.message)) > 1000)
			arguments.message = left(arguments.message,997) & "...";

		sentryMessage = {
			"sentry.interfaces.Message" : {
				"formatted" : arguments.message
			}
		};

		capture(
			captureStruct : sentryMessage,
			path : arguments.path,
			useThread : arguments.useThread,
			userInfo : arguments.userInfo
		);
	}

	/**
	* @exception The exception
	* @level The level to log
	* @path The path to the script currently executing
	* @useThread Option to send post to Sentry in its own thread
	* @userInfo Optional Struct that gets passed to the Sentry User Interface
	* @showJavaStackTrace Passes Java Stack Trace as a string to the extra attribute
	* @oneLineStackTrace Set to true to render only 1 tag context. This is not the Java Stack Trace this is simply for the code output in Sentry
	* @removeTabsOnJavaStackTrace Removes the tab on the child lines in the Stack Trace
	* @additionalData Additional metadata to store with the event - passed into the extra attribute
	*/
	public any function captureException(
		required any exception,
		string level = "error",
		string path = "",
		boolean oneLineStackTrace = false,
		boolean showJavaStackTrace = false,
		boolean removeTabsOnJavaStackTrace = false,
		any additionalData,
		boolean useThread = false,
		struct userInfo = {}
	) {
		var sentryException = {};
		var sentryExceptionExtra = {};
		var file = "";
		var fileArray = "";
		var currentTemplate = "";
		var tagContext = arguments.exception.TagContext;
		var i = 1;
		var st = "";

		validateLevel(arguments.level);

		/*
		* CORE AND OPTIONAL ATTRIBUTES
		* https://docs.sentry.io/clientdev/attributes/
		*/
		local.message = arguments.exception.message;
		if (isdefined("arguments.exception.diagnostics") AND arguments.exception.diagnostics NEQ "") {

			// Append diagnostics if available.  This will show sql error messages.
			if (arguments.exception.diagnostics.startsWith(local.message)) {
				local.message = arguments.exception.diagnostics;
			} else {
				local.message &= " " & arguments.exception.diagnostics;
			}

			// Diagnostics ends with a "the error occurred on" message which is not needed
			// for sentry as we have a stacktrace.
			local.foundBrIndex = findNoCase("<br>The error occurred on line", local.message);
			if (local.foundBrIndex GT len(arguments.exception.message)) {
				local.message = left(local.message, local.foundBrIndex - 1);
			}
		}

		sentryException = {
			"message" 	: local.message,
			"culprit" 	: arguments.exception.message
		};

		if (arguments.showJavaStackTrace){
			st = reReplace(arguments.exception.StackTrace, "\r", "", "All");
			if (arguments.removeTabsOnJavaStackTrace) {
				st = reReplace(st, "\t", "", "All");
			}
			sentryExceptionExtra["Java StackTrace"] = listToArray(st,chr(10));
		}

		if (!isNull(arguments.additionalData))
    	for (currentKey in additionalData) {
				sentryExceptionExtra[currentKey] = additionalData[currentKey];
		};

		if (structCount(sentryExceptionExtra))
			sentryException["extra"] = sentryExceptionExtra;

		/*
		* EXCEPTION INTERFACE
		* https://docs.sentry.io/clientdev/interfaces/exception/
		*/
		sentryException["exception"] = {"values":[{
			"value" : local.message,
			"type" 	: arguments.exception.type & " Error"
			}]
		};

		/*
		* STACKTRACE INTERFACE
		* https://docs.sentry.io/clientdev/interfaces/stacktrace/
		*/
		if (arguments.oneLineStackTrace)
			tagContext = [tagContext[1]];

		sentryException["stacktrace"] = {
			"frames" : []
		};

		for (i=arrayLen(tagContext); i >= 1; i--) {
			if (compareNoCase(tagContext[i]["TEMPLATE"],currentTemplate)) {
				fileArray = [];
				if (fileExists(tagContext[i]["TEMPLATE"])) {
					file = fileOpen(tagContext[i]["TEMPLATE"], "read");
					while (!fileIsEOF(file))
						arrayAppend(fileArray, fileReadLine(file));
					fileClose(file);
				}
				currentTemplate = tagContext[i]["TEMPLATE"];
			}

			local.frame = {
				"abs_path" 	= tagContext[i]["TEMPLATE"],
				"filename" 	= getRelativePath(tagContext[i]["TEMPLATE"]),
				"lineno" 	= tagContext[i]["LINE"],
				"colno"		= tagContext[i]["COLUMN"],
				"function"	= tagContext[i]["ID"],
				"in_app"	= true
			};
			arrayAppend(sentryException["stacktrace"]["frames"], local.frame);

			// for source code rendering
			local.frame["pre_context"] = [];
			if (tagContext[i]["LINE"]-3 >= 1)
				local.frame["pre_context"][1] = fileArray[tagContext[i]["LINE"]-3];
			if (tagContext[i]["LINE"]-2 >= 1)
				local.frame["pre_context"][2] = fileArray[tagContext[i]["LINE"]-2];
			if (tagContext[i]["LINE"]-1 >= 1)
				local.frame["pre_context"][3] = fileArray[tagContext[i]["LINE"]-1];

			if (arrayLen(fileArray))
				local.frame["context_line"] = fileArray[tagContext[i]["LINE"]];

			local.frame["post_context"] = [];
			if (arrayLen(fileArray) >= tagContext[i]["LINE"]+1)
				local.frame["post_context"][1] = fileArray[tagContext[i]["LINE"]+1];
			if (arrayLen(fileArray) >= tagContext[i]["LINE"]+2)
				local.frame["post_context"][2] = fileArray[tagContext[i]["LINE"]+2];

			for (local.nonAppPattern in nonAppPathPatterns) {
				if (reFindNoCase(local.nonAppPattern, local.frame.abs_path) > 0) {
					local.frame["in_app"] = false;
					break;
				}
			}
		}

		capture(
			captureStruct : sentryException,
			path : arguments.path,
			useThread : arguments.useThread,
			userInfo : arguments.userInfo
		);
	}

	/**
	* Returns the relative path from the root of the website. Defaults to filePath if
	* no relative path exists.
	*/
	private String function getRelativePath(String filePath) {
		try {
			local.pathsClass = createObject("java", "java.nio.file.Paths");
			local.root = local.pathsClass.get(expandPath("\"), []);
			local.target = local.pathsClass.get(arguments.filePath, []);

			return local.root.relativize(local.target).toString();
		} catch (any ex) {
			// if target is not a subpath of root, fallback to absolute path.
			return filePath;
		}
	}

	/**
	* Prepare message to post to Sentry
	*
	* @captureStruct The struct we are passing to Sentry
	* @path The path to the script currently executing
	* @useThread Option to send post to Sentry in its own thread
	* @userInfo Optional Struct that gets passed to the Sentry User Interface
	*/
	public void function capture(
		required any captureStruct,
		string path = "",
		boolean useThread = false,
		struct userInfo = {}
	) {
		var jsonCapture = "";
		var signature = "";
		var header = "";
		var timeVars = getTimeVars();
		var httpRequestData = getHTTPRequestData();

		// Add global metadata
		arguments.captureStruct["event_id"] = lcase(replace(createUUID(), "-", "", "all"));
		arguments.captureStruct["timestamp"] = timeVars.timeStamp;
		arguments.captureStruct["logger"] = getLogger();
		arguments.captureStruct["project"] = getProjectID();
		arguments.captureStruct["server_name"] = getServerName();
		arguments.captureStruct["platform"] = getPlatform();
		arguments.captureStruct["release"] = getRelease();
		arguments.captureStruct["environment"] = getEnvironment();
		arguments.captureStruct["level"] = getLevel();

		/*
		* User interface
		* https://docs.sentry.io/clientdev/interfaces/user/
		*
		* {
		*     "id" : "unique_id",
		*     "email" : "my_user",
		*     "ip_address" : "foo@example.com",
		*     "username" : "127.0.0.1",
		*			"arbitrary" : "foo-bar"
		* }
		*
		* All other keys are stored as extra information but not specifically processed by sentry.
		*/
		if (!structIsEmpty(arguments.userInfo))
			arguments.captureStruct["user"] = arguments.userInfo;

		// Prepare path for HTTP Interface
		arguments.path = trim(arguments.path);
		if (!len(arguments.path))
			arguments.path = "https://" & cgi.server_name & cgi.script_name;

		// HTTP interface
		// https://docs.sentry.io/clientdev/interfaces/http/
		arguments.captureStruct["request"] = {
				"url" : arguments.path,
				"method" : cgi.request_method,
				"data": form,
				"query_string" : cgi.query_string,
				"cookies" : cookie,
				"env": cgi,
				"headers": httpRequestData.headers
			};


		// encode data
		jsonCapture = jsonEncode(arguments.captureStruct);
		// prepare header
		header = "Sentry sentry_version=#getSentryVersion()#, sentry_timestamp=#timeVars.time#, sentry_key=#getPublicKey()#, sentry_secret=#getPrivateKey()#, sentry_client=#getLogger()#/#getVersion()#";
		// post message
		if (arguments.useThread){
			thread
				action = "run"
				name = "sentry-thread-" & createUUID()
				header = header
				jsonCapture = jsonCapture,
				application = application
			{
				post(header,jsonCapture);
			}
		} else {
			post(header,jsonCapture);
		}
	}

	/**
	* Post message to Sentry
	*/
	private void function post(
		required string header,
		required string json
	) {
		if(!structKeyExists(application, "sentryRetryAfter") ||
				(structKeyExists(application, "sentryRetryAfter") && isDate(application.sentryRetryAfter) && Now() gte application.sentryRetryAfter)) {
			var res = {};
			// send to sentry via REST API Call
			local.httpService = new http(
				url = getSentryUrl() & "/api/store/",
				method = "post",
				timeout : "15",
				charset = "utf-8"
			);
			local.httpService.addParam(type="header",name="X-Sentry-Auth",value=arguments.header);
			local.httpService.addParam(type="body",value=arguments.json);
			res = httpService.send().getPrefix();
		} else {
				cflog(application=true, file="Sentry-cfml-warning", text="Dropped error payload due to 429 Too Many Requests in effect.", type="warning");
		}

		if (!find("200", res.statuscode)){
			if(find("429", res.statuscode)){
				var retry = numberFormat(res.headers["retry-after"],"9"); // comes in as seconds floating point
				application.sentryRetryAfter = dateAdd("s", retry, Now());
				cflog(application=true, file="Sentry-cfml-warning", text="429 Too Many Requests #res.filecontent# retrying after #application.sentryRetryAfter#", type="warning");
			} else {
				cflog(application=true, file="Sentry-cfml-Error", text="Sentry failure", type="error");
			}
		}
	}
	private string function jsonEncode(
		required any data
	) {
		local.serializer = new customJsonSerializer();

		local.serializer.asInteger("lineno");
		local.serializer.asInteger("colno");
		local.serializer.asBoolean("in_app");

		return local.serializer.serialize(arguments.data);
	}

	/**
	* Get UTC time values
	*/
	private struct function getTimeVars() {
		var time = now();
		var timeVars = {
			"time" : time.getTime(),
			"utcNowTime" : dateConvert("Local2UTC", time)
		};
		timeVars.timeStamp = dateformat(timeVars.utcNowTime, "yyyy-mm-dd") & "T" & timeFormat(timeVars.utcNowTime, "HH:mm:ss");
		return timeVars;
	}
}
