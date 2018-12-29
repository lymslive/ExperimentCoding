sub p_system_path_test
{
	require "Speech.pm";
	return jr({
			INC => \@INC,
			SpeechFile => $INC{"Speech.pm"},
			SpeechVersion => $Speech::VERSION,
		});
}
