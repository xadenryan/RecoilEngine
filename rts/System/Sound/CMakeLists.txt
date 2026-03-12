
# only one of the two targets needs this
remove_definitions(-DNO_SOUND)

# Dummy Sound implementation
set(noSoundSources
		IAudioChannel.cpp
		ISound.cpp
		Null/SoundChannels.cpp
		Null/NullSound.cpp
	)

add_library(no-sound STATIC EXCLUDE_FROM_ALL ${noSoundSources})
set_target_properties(no-sound PROPERTIES COMPILE_FLAGS "-DNO_SOUND")
target_link_libraries(no-sound Tracy::TracyClient)

# Define default sound implementation
if    (NO_SOUND)
	set(sound-impl no-sound PARENT_SCOPE)
else  (NO_SOUND)
	set(sound-impl sound PARENT_SCOPE)
endif (NO_SOUND)


# Real Sound implementation
if    (NOT NO_SOUND)
	set(soundSources
			ISound.cpp
			IAudioChannel.cpp
			Null/NullSound.cpp
			OpenAL/ALShared.cpp
			OpenAL/EFX.cpp
			OpenAL/EFXfuncs.cpp
			OpenAL/EFXPresets.cpp
			OpenAL/AudioChannel.cpp
			OpenAL/OggDecoder.cpp
			OpenAL/Mp3Decoder.cpp
			OpenAL/MusicStream.cpp
			OpenAL/Sound.cpp
			OpenAL/SoundChannels.cpp
			OpenAL/SoundBuffer.cpp
			OpenAL/SoundItem.cpp
			OpenAL/SoundSource.cpp
			OpenAL/VorbisShared.cpp
		)

	if (APPLE)
		# Prefer Homebrew openal-soft on macOS because Apple's OpenAL framework
		# does not expose the EFX surface this sound path expects.
		find_path(OPENAL_SOFT_INCLUDE_DIR
			NAMES al.h
			PATHS
				/opt/homebrew/opt/openal-soft/include/AL
				/usr/local/opt/openal-soft/include/AL
			NO_DEFAULT_PATH
		)
		find_library(OPENAL_SOFT_LIBRARY
			NAMES openal
			PATHS
				/opt/homebrew/opt/openal-soft/lib
				/usr/local/opt/openal-soft/lib
			NO_DEFAULT_PATH
		)

		if (OPENAL_SOFT_INCLUDE_DIR AND OPENAL_SOFT_LIBRARY)
			set(OPENAL_INCLUDE_DIR "${OPENAL_SOFT_INCLUDE_DIR}" CACHE PATH "Preferred OpenAL include directory" FORCE)
			set(OPENAL_LIBRARY "${OPENAL_SOFT_LIBRARY}" CACHE FILEPATH "Preferred OpenAL library" FORCE)
		endif()
	endif()

	find_package_static(OpenAL 1.18.2 REQUIRED)
	find_package_static(OggVorbis 1.3.4 REQUIRED)

	find_package(SDL2 MODULE REQUIRED)

	include_directories(${CMAKE_SOURCE_DIR}/include/)
	include_directories(${CMAKE_SOURCE_DIR}/include/AL)

	add_library(sound STATIC EXCLUDE_FROM_ALL ${soundSources})
	target_link_libraries(sound SDL2::SDL2)
	target_link_libraries(sound vorbis::vorbisfile vorbis::vorbis Ogg::ogg)
	target_link_libraries(sound OpenAL::OpenAL)
	target_link_libraries(sound Tracy::TracyClient)
	target_link_libraries(sound nowide::nowide)
endif (NOT NO_SOUND)
