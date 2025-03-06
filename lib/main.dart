import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gensite/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

// Debug mode flag - set to false to use actual backend
const bool kDebugMode = false;

// Pre-generated meditation content for debug mode
const Map<String, String> kDebugMeditations = {
  'anxiety': '''Close your eyes and take a long, deep breath. Allow your shoulders to relax as you exhale completely.

Feel the weight of anxiety begin to dissolve with each breath. Your mind, like the night sky above, is vast and boundless - your anxious thoughts are merely passing clouds.

Bring your attention to your body, starting from your toes. With each inhale, imagine cool, calming energy entering. With each exhale, tension melts away.

Notice the sensations in your feet... your legs... your torso... your arms... your neck... and finally your head. Your body is becoming heavier, more relaxed with each breath.

The universe has existed for billions of years, and will continue long after our concerns have faded. In this cosmic perspective, today's worries are but tiny specks.

You are safe in this moment. Nothing requires your immediate attention or concern. The simple act of breathing is all that matters now.

When anxious thoughts arise, simply observe them like stars in the night sky. No need to reach for them or push them away - just acknowledge their presence and let them be.

Remember that you are not your thoughts. You are the awareness watching them come and go, like constellations moving across the vast expanse of your consciousness.

Carry this starlit calm with you as you slowly return to awareness of your surroundings.''',

  'sleep': '''Make yourself comfortable, allowing your body to sink heavily into your bed. Feel the gentle support beneath you.

Your only task now is to follow your breath as it naturally flows in and out, like gentle waves on a moonlit shore.

With each exhale, feel yourself drifting deeper into relaxation. Your eyelids are becoming heavier, your thoughts slower.

Imagine a soft, cosmic light surrounding your body, gradually relaxing each part as it touches you. From your toes to the crown of your head, every muscle releases its tension.

The night sky above you is filled with countless stars, each one watching over you as you prepare for rest. Their gentle light bathes you in tranquility.

Your mind is slowing down now, thoughts becoming distant and dreamlike. There is nothing to analyze, nothing to solve, nothing to plan.

Feel yourself floating in this peaceful space between wakefulness and sleep. Like an astronaut drifting in the serene void of space, you are weightless and free.

Time stretches out infinitely before you. There is no rush, nowhere to be, nothing to do but surrender to the embrace of sleep.

Your breath is becoming slower, deeper. Your consciousness is beginning to drift like a feather on a gentle breeze.

Allow yourself to let go completely now, surrendering to the healing power of deep, restorative sleep.''',

  'stress': '''Take a moment to settle into a comfortable position. Allow your breath to find its natural rhythm.

As you breathe in, imagine drawing in cosmic energy from the universe around you. As you breathe out, release the tension you've been carrying.

Feel the weight of stress and responsibility gradually lifting from your shoulders with each exhale. Like stars scattered across the night sky, your concerns can be observed from a distance.

Bring awareness to any areas of tension in your body. Perhaps your jaw, your shoulders, or your hands. With gentle attention, invite these areas to soften and release.

The demands of daily life often create the illusion of urgency. In this moment, recognize that very few things require immediate attention. Time is more expansive than it appears.

Imagine your mind as a clear night sky. Thoughts may appear like shooting stars, briefly illuminating your awareness before fading away. There's no need to chase them.

With each breath, you're creating space between yourself and your stressors. This space is filled with clarity, perspective, and calm.

Remember that you have navigated challenges before, and you carry that wisdom with you always. Trust in your ability to handle whatever comes your way.

When you're ready, carry this sense of spacious calm back into your day, knowing you can return to this peaceful state whenever you choose.''',

  'focus': '''Begin by taking a deep, centering breath. Feel your lungs expand fully, and then release completely.

Direct your attention to this present moment. Like a telescope focusing on a single distant star, your mind can zoom in with remarkable clarity when not scattered across the galaxy of distractions.

Notice any sounds in your environment without judging them. Simply acknowledge their presence and let them fade into the background of your awareness.

Now bring your attention to the sensation of your breath at the tip of your nostrils. Cool air flowing in, warm air flowing out. This single point of focus becomes your anchor.

When you notice your mind wandering—as it naturally will—gently guide it back to your breath with kindness. Each return is a strengthening of your mental focus.

Imagine your concentration as a beam of light, illuminating exactly what needs your attention right now. Everything else can remain in soft darkness, waiting for its moment.

With each breath, your mind becomes clearer, more alert, more present. Distractions lose their pull as you cultivate this quality of focused awareness.

Feel the satisfaction that comes with directing your mind where you choose, rather than being pulled in multiple directions. This is the power of concentrated attention.

Carry this focused awareness with you as you return to your tasks, knowing you can reconnect with this state whenever you need clarity and direction.''',

  'confidence': '''Sit or stand in a position that feels strong and dignified. Take a deep breath and straighten your spine, allowing your shoulders to relax downward.

As you breathe in, imagine drawing in the brilliant energy of a supernova, filling your entire being with light and power. As you exhale, release any self-doubt or hesitation.

Bring to mind a moment when you felt truly capable and confident. Remember how your body felt, what thoughts were present, and the energy that flowed through you. Know that this state is always accessible to you.

Picture yourself as a magnificent celestial body—a star that generates its own light. You don't need external validation to shine; it's your natural state.

Consider the vast universe and your unique place within it. No one else has your specific combination of talents, experiences, and perspectives. Your contribution matters.

With each breath, repeat silently to yourself: "I am capable. I am worthy. I am enough." Let these truths sink deeply into your consciousness.

Imagine roots extending from your body deep into the earth, providing unwavering stability and confidence. At the same time, feel your energy extending upward, connecting to infinite possibility.

When you encounter challenges, they are simply opportunities to shine more brightly. Difficulty reveals your strength, not your limitations.

Carry this celestial confidence with you as you return to your day, knowing that like the stars themselves, your inner light is constant, even when temporarily obscured from view.''',

  'gratitude': '''Begin by taking a few deep breaths, allowing your body to relax and your mind to become present. Feel yourself settling into this moment.

Bring your awareness to the miracle of existence itself. Like a rare celestial event, the chances of you being here, now, in this form, are infinitesimally small yet gloriously real.

Consider your connection to the stars themselves. The elements that form your body were forged in the heart of ancient stars billions of years ago. You are, quite literally, made of stardust.

Think of one person who has positively impacted your life. Feel the warmth of gratitude spreading through your chest as you acknowledge their gift to you, whether large or small.

Bring to mind something in nature that fills you with wonder—perhaps the night sky, the ocean, or a single flower. Take a moment to appreciate the beauty that exists all around us, freely offered.

Acknowledge your own body and the countless processes it performs without any conscious effort from you. Your beating heart, your breathing lungs, your intricate brain—all working in perfect harmony.

Consider a challenge you've faced that ultimately led to growth. Express gratitude for this difficulty and the strength it helped you discover.

Expand your awareness to include the vast network of people, plants, animals, and systems that make your daily life possible. From farmers to truck drivers, from rain clouds to pollinators—all playing their part in supporting your existence.

Carry this constellation of gratitude with you throughout your day, knowing that an appreciative heart creates space for even more abundance and joy.''',

  'grounding': '''Find a comfortable position and take a deep breath in through your nose. As you exhale through your mouth, feel yourself becoming more present in this moment.

Imagine cosmic roots extending from the base of your spine deep into the Earth. With each breath, these roots grow stronger, anchoring you firmly to the ground beneath you.

Bring your awareness to the points where your body makes contact with the floor or chair. Feel the solid support beneath you, holding you securely.

Notice five things you can see around you. Observe their colors, shapes, and textures with full attention, as if seeing them for the first time.

Become aware of four things you can touch. Perhaps the texture of your clothing, the temperature of the air on your skin, or the surface beneath your hands.

Listen for three distinct sounds in your environment. Without labeling them as pleasant or unpleasant, simply notice their qualities and how they arise and fade.

Identify two scents you can smell, or simply notice the sensation of air entering your nostrils as you breathe.

Finally, notice one taste in your mouth, even if it's subtle.

Feel how this simple practice has drawn you back from the vastness of thought into the reality of your physical experience. Like a meteor returning to Earth, you have come back to the ground of your being.

Carry this embodied presence with you as you move through your day, knowing you can return to this grounded state whenever you feel adrift or overwhelmed.''',
};

void main() {
  runApp(const MeditationApp());
}

class MeditationApp extends StatelessWidget {
  const MeditationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oneiro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF8B5CF6), // Purple
          secondary: const Color(0xFFEC4899), // Pink
          background: const Color(0xFF0F172A), // Dark blue
          surface: const Color(0xFF1E293B), // Lighter blue
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B).withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: const Color(0xFF8B5CF6), width: 2),
          ),
          hintStyle: const TextStyle(color: Colors.white60),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  bool _isLoading = false;
  String _meditation = '';
  bool _isScriptExpanded = false;
  
  // Job tracking
  String? _jobId;
  Timer? _pollingTimer;
  int _pollCount = 0;
  int _progressPercent = 0;
  String _statusMessage = '';
  
  // Audio player state
  bool _isPlaying = false;
  double _audioProgress = 0.0;
  late AnimationController _audioProgressController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _audioUrl;
  
  // Animation controllers
  late final List<AnimationController> _starControllers;
  late final List<Animation<double>> _starAnimations;
  final int _starCount = 150;
  final math.Random _random = math.Random();
  
  // Star positions
  late final List<Offset> _starPositions;
  late final List<double> _starSizes;

  @override
  void initState() {
    super.initState();
    
    // Initialize audio progress controller
    _audioProgressController = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 5), // Typical meditation length
    )..addListener(() {
      setState(() {
        _audioProgress = _audioProgressController.value;
      });
    });

    // Initialize audio player
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
          _audioProgress = 0.0;
        });
        _audioProgressController.reset();
      }
    });

    _audioPlayer.positionStream.listen((position) {
      if (_audioPlayer.duration != null) {
        final progress = position.inMilliseconds / _audioPlayer.duration!.inMilliseconds;
        setState(() {
          _audioProgress = progress.clamp(0.0, 1.0);
        });
      }
    });
    
    // Initialize star animations
    _starControllers = List.generate(
      _starCount,
      (index) => AnimationController(
        duration: Duration(milliseconds: _random.nextInt(2000) + 1000),
        vsync: this,
      ),
    );
    
    _starAnimations = List.generate(
      _starCount,
      (index) => Tween<double>(
        begin: 0.1 + _random.nextDouble() * 0.5,
        end: 0.7 + _random.nextDouble() * 0.3,
      ).animate(
        CurvedAnimation(
          parent: _starControllers[index],
          curve: Curves.easeInOut,
        ),
      ),
    );
    
    // Generate random positions for stars
    _starPositions = List.generate(
      _starCount,
      (index) => Offset(
        _random.nextDouble(),
        _random.nextDouble(),
      ),
    );
    
    // Generate random sizes for stars
    _starSizes = List.generate(
      _starCount,
      (index) => 1 + _random.nextDouble() * 2,
    );
    
    // Start animations with random delays
    for (int i = 0; i < _starCount; i++) {
      Future.delayed(Duration(milliseconds: _random.nextInt(2000)), () {
        if (mounted) {
          _starControllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _audioProgressController.dispose();
    _audioPlayer.dispose();
    _pollingTimer?.cancel();
    for (final controller in _starControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_audioUrl == null) return;
    
    setState(() {
      _isPlaying = !_isPlaying;
    });
    
    if (_isPlaying) {
      // If we haven't loaded the audio yet, load it
      if (_audioPlayer.duration == null) {
        try {
          await _audioPlayer.setUrl(_audioUrl!);
          await _audioPlayer.play();
        } catch (e) {
          print('Error playing audio: $e');
          setState(() {
            _isPlaying = false;
          });
        }
      } else {
        await _audioPlayer.play();
      }
    } else {
      await _audioPlayer.pause();
    }
  }

  void _resetAudioPlayer() {
    _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _audioProgress = 0.0;
      _audioUrl = null;
    });
  }

  void _startPollingJobStatus() {
    // Cancel any existing timer
    _pollingTimer?.cancel();
    
    // Initialize polling variables
    _pollCount = 0;
    
    // Start polling
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _pollJobStatus();
      
      // Increment poll count
      _pollCount++;
      
      // If we've been polling for too long (2 minutes), stop
      if (_pollCount > 60) {
        timer.cancel();
        setState(() {
          _isLoading = false;
          _meditation = 'Sorry, the meditation is taking longer than expected. Please try again.';
        });
      }
    });
  }
  
  Future<void> _pollJobStatus() async {
    if (_jobId == null) return;
    
    try {
      final response = await ApiService.getMeditationStatus(_jobId!);
      
      setState(() {
        _progressPercent = response['progress'] ?? 0;
        
        // Update status message
        final status = response['status'];
        if (status == 'generating_script') {
          _statusMessage = 'Creating your personalized meditation script...';
        } else if (status == 'generating_audio') {
          _statusMessage = 'Generating soothing audio for your meditation...';
        }
      });
      
      // Check if the job is completed
      if (response['status'] == 'completed') {
        _pollingTimer?.cancel();
        
        setState(() {
          _meditation = response['meditation_script'] ?? '';
          _audioUrl = response['audio_url'];
          _isLoading = false;
          _statusMessage = '';
        });
      }
      
      // Check if there was an error
      else if (response['status'] == 'error') {
        _pollingTimer?.cancel();
        
        setState(() {
          _meditation = 'Sorry, we encountered an error: ${response['error']}';
          _isLoading = false;
          _statusMessage = '';
        });
      }
      
    } catch (e) {
      print('Error polling job status: $e');
      // Don't cancel the timer on error, just keep trying
    }
  }

  Future<void> _generateMeditation() async {
    final stressDescription = _inputController.text.trim();
    if (stressDescription.isEmpty) return;

    setState(() {
      _isLoading = true;
      _meditation = '';
      _progressPercent = 0;
      _statusMessage = 'Starting meditation generation...';
    });
    
    // Reset audio player whenever we generate a new meditation
    _resetAudioPlayer();

    try {
      if (kDebugMode) {
        // Simulate network delay
        await Future.delayed(const Duration(seconds: 1));
        
        // Use debug content based on keywords in input
        final input = stressDescription.toLowerCase();
        String result = '';
        
        if (input.contains('anxious') || input.contains('anxiety') || input.contains('worry')) {
          result = kDebugMeditations['anxiety']!;
        } else if (input.contains('sleep') || input.contains('insomnia') || input.contains('tired')) {
          result = kDebugMeditations['sleep']!;
        } else if (input.contains('stress') || input.contains('overwhelm') || input.contains('pressure')) {
          result = kDebugMeditations['stress']!;
        } else if (input.contains('focus') || input.contains('concentrate') || input.contains('distract')) {
          result = kDebugMeditations['focus']!;
        } else if (input.contains('confidence') || input.contains('doubt') || input.contains('afraid')) {
          result = kDebugMeditations['confidence']!;
        } else if (input.contains('gratitude') || input.contains('thankful') || input.contains('appreciate')) {
          result = kDebugMeditations['gratitude']!;
        } else if (input.contains('ground') || input.contains('center') || input.contains('present')) {
          result = kDebugMeditations['grounding']!;
        } else {
          // Default to a random meditation for other inputs
          final keys = kDebugMeditations.keys.toList();
          final randomKey = keys[_random.nextInt(keys.length)];
          result = kDebugMeditations[randomKey]!;
        }
        
        setState(() {
          _meditation = result;
          _isLoading = false;
        });
      } else {
        // Use actual API in non-debug mode
        final response = await ApiService.processText(stressDescription);
        
        // If we got an immediate response (e.g. sample or error)
        if (response['status'] == 'success' && response['meditation'] != null) {
          setState(() {
            _meditation = response['meditation'];
            _isLoading = false;
            
            // Handle audio URL if available
            if (response['audioUrl'] != null && response['audioUrl'].isNotEmpty) {
              _audioUrl = response['audioUrl'];
            }
          });
        } 
        // If we got a job ID for an asynchronous job
        else if (response['job_id'] != null) {
          _jobId = response['job_id'];
          _startPollingJobStatus();
        } 
        // If we got an error
        else {
          setState(() {
            _meditation = response['meditation'] ?? 'Sorry, we had trouble generating your meditation.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _meditation = 'Sorry, we had trouble generating your meditation. Please try again.';
        _isLoading = false;
      });
    }
  }

  // Toggle script expansion
  void _toggleScript() {
    setState(() {
      _isScriptExpanded = !_isScriptExpanded;
    });
  }

  // Download meditation audio
  void _downloadAudio() {
    if (_audioUrl != null) {
      ApiService.downloadMeditationAudio(_audioUrl!, 'meditation.wav');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.5,
                colors: [
                  const Color(0xFF8B5CF6).withOpacity(0.15),
                  Theme.of(context).colorScheme.background,
                ],
              ),
            ),
          ),
          
          // Animated stars
          Stack(
            children: List.generate(_starCount, (index) {
              return AnimatedBuilder(
                animation: _starAnimations[index],
                builder: (context, child) {
                  return Positioned(
                    left: _starPositions[index].dx * screenSize.width,
                    top: _starPositions[index].dy * screenSize.height,
                    child: Container(
                      width: _starSizes[index],
                      height: _starSizes[index],
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(_starAnimations[index].value),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(_starAnimations[index].value * 0.5),
                            blurRadius: 4 * _starAnimations[index].value,
                            spreadRadius: 1 * _starAnimations[index].value,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
          
          // Main content with padding
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 80),
                    
                    // App title
                    Text(
                      'Oneiro',
                      style: GoogleFonts.inter(
                        fontSize: 48, 
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        color: Colors.white,
                        letterSpacing: -1.0,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Tagline
                    Text(
                      'AI-Powered Meditation Generator',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Main card with input and output
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Input section
                          TextField(
                            controller: _inputController,
                            decoration: InputDecoration(
                              hintText: 'Tell me what\'s on your mind...',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  Icons.spa_rounded, 
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: _isLoading ? null : _generateMeditation,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            onSubmitted: (_) => _generateMeditation(),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Loading indicator or meditation content
                          if (_isLoading)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                LinearProgressIndicator(
                                  value: _progressPercent > 0 ? _progressPercent / 100 : null,
                                  backgroundColor: Colors.white.withOpacity(0.1),
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _statusMessage,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const CircularProgressIndicator(),
                              ],
                            )
                          else if (_meditation.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Expandable meditation text
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isScriptExpanded
                                          ? _meditation
                                          : _meditation.split('\n\n').take(2).join('\n\n') + '\n\n...',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          height: 1.8,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Center(
                                        child: TextButton(
                                          onPressed: _toggleScript,
                                          child: Text(
                                            _isScriptExpanded ? 'Show Less' : 'Show More',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Audio player controls
                                if (_audioUrl != null)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      children: [
                                        // Progress bar
                                        SliderTheme(
                                          data: SliderThemeData(
                                            trackHeight: 4,
                                            activeTrackColor: Theme.of(context).colorScheme.primary,
                                            inactiveTrackColor: Colors.white.withOpacity(0.2),
                                            thumbColor: Theme.of(context).colorScheme.primary,
                                            thumbShape: const RoundSliderThumbShape(
                                              enabledThumbRadius: 6,
                                            ),
                                          ),
                                          child: Slider(
                                            value: _audioProgress,
                                            onChanged: (value) {
                                              if (_audioPlayer.duration != null) {
                                                final position = Duration(
                                                  milliseconds: (value * _audioPlayer.duration!.inMilliseconds).round(),
                                                );
                                                _audioPlayer.seek(position);
                                              }
                                            },
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 8),
                                        
                                        // Play/pause button and download button
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                                              color: Theme.of(context).colorScheme.primary,
                                              iconSize: 48,
                                              onPressed: _togglePlayPause,
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.download),
                                              color: Colors.white70,
                                              onPressed: _downloadAudio,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Footer text with attribution
                    Text(
                      'Crafted with cosmic energy by Oneiro',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper method to format duration
String _formatDuration(double seconds) {
  final int mins = seconds ~/ 60;
  final int secs = seconds.toInt() % 60;
  return '$mins:${secs.toString().padLeft(2, '0')}';
}
