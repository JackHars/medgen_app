import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gensite/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

// Debug mode flag - set to true to use local development backend
const bool kDebugMode = true;

// No pre-generated content - all meditations come from the backend

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
  bool _isAudioLoading = false;
  double _audioProgress = 0.0;
  Duration? _audioDuration;
  late AnimationController _audioProgressController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _audioUrl;
  String? _audioError;
  
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
      duration: const Duration(minutes: 5), // Default duration, will be updated
    )..addListener(() {
      setState(() {
        _audioProgress = _audioProgressController.value;
      });
    });

    // Initialize audio player
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
        
        // Handle completion
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _audioProgress = 0.0;
          _audioProgressController.reset();
        }
      });
    });

    _audioPlayer.positionStream.listen((position) {
      if (_audioPlayer.duration != null) {
        final progress = position.inMilliseconds / _audioPlayer.duration!.inMilliseconds;
        setState(() {
          _audioProgress = progress.clamp(0.0, 1.0);
        });
      }
    });
    
    _audioPlayer.durationStream.listen((duration) {
      setState(() {
        _audioDuration = duration;
      });
    });
    
    // Listen for errors
    _audioPlayer.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        setState(() {
          _audioError = 'Error loading audio: ${e.toString()}';
          _isAudioLoading = false;
        });
      },
    );
    
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
    
    // If there was an error, reset and try again
    if (_audioError != null) {
      _resetAudioPlayer();
      setState(() {
        _audioError = null;
      });
    }
    
    if (_isPlaying) {
      // If already playing, just pause
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      // Show pause button immediately for better UX
      setState(() {
        _isPlaying = true;
        // We'll keep _isAudioLoading internal and not show it in the UI
        _isAudioLoading = true;
      });
      
      try {
        // If we haven't loaded the audio yet, load it
        if (_audioPlayer.duration == null) {
          // If it's a relative URL, prepend the base URL
          final String fullUrl = _audioUrl!.startsWith('http') 
              ? _audioUrl! 
              : '${ApiService.baseUrl}${_audioUrl!}';
              
          print('Loading audio from: $fullUrl');
          
          await _audioPlayer.setUrl(fullUrl);
          await _audioPlayer.play();
        } else {
          // Resume playback
          await _audioPlayer.play();
        }
        
        // Update state once loading is complete
        setState(() {
          _isAudioLoading = false;
        });
      } catch (e) {
        print('Error playing audio: $e');
        setState(() {
          _isAudioLoading = false;
          _isPlaying = false;
          _audioError = 'Error playing audio: ${e.toString()}';
        });
      }
    }
  }

  void _resetAudioPlayer() {
    _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _isAudioLoading = false;
      _audioProgress = 0.0;
      _audioUrl = null;
      _audioError = null;
      _audioDuration = null;
    });
  }
  
  void _seekAudio(double value) {
    if (_audioDuration != null) {
      final position = Duration(
        milliseconds: (value * _audioDuration!.inMilliseconds).round(),
      );
      _audioPlayer.seek(position);
    }
  }

  void _startPollingJobStatus() {
    // Cancel any existing timer
    _pollingTimer?.cancel();
    
    // Initialize polling variables
    _pollCount = 0;
    
    setState(() {
      _statusMessage = 'Starting meditation generation...';
      _progressPercent = 5; // Start with a small progress indication
    });
    
    // Start polling
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _pollJobStatus();
      
      // Increment poll count
      _pollCount++;
      
      // If we've been polling for too long (10 minutes), stop
      if (_pollCount > 300) {
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
        // Update progress percentage
        _progressPercent = response['progress'] ?? _progressPercent;
        
        // Update status message based on server status
        final status = response['status'];
        switch (status) {
          case 'initializing':
            _statusMessage = 'Initializing your meditation...';
            break;
          case 'generating_script':
            _statusMessage = 'Creating your personalized meditation script...';
            break;
          case 'preparing_audio':
            _statusMessage = 'Preparing for audio generation...';
            break;
          case 'generating_audio':
            // For audio generation, check if there's a substage available
            final substage = response['substage'];
            if (substage == 'initializing') {
              _statusMessage = 'Setting up the voice generation model...';
            } else if (substage == 'chunking') {
              _statusMessage = 'Analyzing your meditation text...';
            } else if (substage == 'processing') {
              // Show which chunk is being processed
              final current = response['current'] ?? 0;
              final total = response['total'] ?? 1;
              _statusMessage = 'Generating your meditation voice (part ${current} of ${total})...';
            } else if (substage == 'post_processing') {
              _statusMessage = 'Adding ambient background sounds to your meditation...';
            } else {
              _statusMessage = 'Generating soothing audio for your meditation...';
            }
            break;
          case 'finalizing':
            _statusMessage = 'Finalizing your meditation...';
            break;
          default:
            _statusMessage = 'Processing your meditation...';
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
      // But update the status message to show we're still working
      setState(() {
        _statusMessage = 'Still waiting for your meditation (this may take a few minutes)...';
      });
    }
  }

  Future<void> _generateMeditation() async {
    final stressDescription = _inputController.text.trim();
    if (stressDescription.isEmpty) return;

    // Reset and start loading state
    setState(() {
      _isLoading = true;
      _meditation = '';
      _progressPercent = 0;
      _statusMessage = 'Connecting to meditation server...';
      _jobId = null; // Reset job ID
    });
    
    // Reset audio player whenever we generate a new meditation
    _resetAudioPlayer();

    try {
      // Send request to the backend server
      final response = await ApiService.processText(stressDescription);
      
      // Check if response contains a job ID for async processing
      if (response.containsKey('job_id')) {
        _jobId = response['job_id'];
        print('Started async job: $_jobId');
        _startPollingJobStatus();
      } 
      // If we got an immediate response with meditation content
      else if (response['status'] == 'success' && response['meditation'] != null) {
        setState(() {
          _meditation = response['meditation'];
          _isLoading = false;
          
          // Handle audio URL if available
          if (response['audioUrl'] != null && response['audioUrl'].isNotEmpty) {
            _audioUrl = response['audioUrl'];
          }
        });
      } 
      // If we got an error response
      else {
        setState(() {
          _meditation = response['meditation'] ?? 'Sorry, we had trouble generating your meditation.';
          _isLoading = false;
        });
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
      // If it's a relative URL, prepend the base URL
      final String fullUrl = _audioUrl!.startsWith('http') 
          ? _audioUrl! 
          : '${ApiService.baseUrl}${_audioUrl!}';
      
      ApiService.downloadMeditationAudio(fullUrl, 'meditation.wav');
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
          
          // Main content
          SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Navigation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0), // Horizontal flip
                                child: Icon(
                                  Icons.nightlight_round,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 30, // 25% bigger than original 24
                                ),
                              ),
                              const SizedBox(width: 16), // Increased spacing for better balance
                              Text(
                                'Oneiro',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'Beta',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 80),
                      
                      // Hero section
                      Column(
                        children: [
                          Text(
                            'From worries to wisdom,',
                            style: GoogleFonts.inter(
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'one breath away.',
                            style: GoogleFonts.inter(
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.5),
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 60),
                      
                      // Input section
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withOpacity(0.2),
                            width: 1,
                          ),
                          color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Icon(
                                Icons.spa_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _inputController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Tell us what\'s troubling you...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                ),
                                onSubmitted: (_) => _generateMeditation(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              margin: const EdgeInsets.all(4),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _generateMeditation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? _buildLoadingIndicator()
                                    : const Text('Generate'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Meditation Result
                      if (_isLoading)
                        _buildProgressBar()
                      else if (_meditation.isNotEmpty) ...[
                        const SizedBox(height: 48),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFF8B5CF6).withOpacity(0.2),
                              width: 1,
                            ),
                            color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
                          ),
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.self_improvement,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'Your Guided Meditation',
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              
                              // Audio Player
                              if (_audioUrl != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF8B5CF6).withOpacity(0.15),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Audio Error Message
                                      if (_audioError != null)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Text(
                                            _audioError!,
                                            style: TextStyle(
                                              color: Colors.red[300],
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                    
                                      Row(
                                        children: [
                                          // Play/Pause button
                                          IconButton(
                                            onPressed: _togglePlayPause,
                                            icon: Icon(
                                                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                                color: Theme.of(context).colorScheme.primary,
                                                size: 40,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          
                                          // Progress bar
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                SliderTheme(
                                                  data: SliderThemeData(
                                                    trackHeight: 8,
                                                    activeTrackColor: Theme.of(context).colorScheme.primary,
                                                    inactiveTrackColor: Theme.of(context).colorScheme.surface,
                                                    thumbColor: Colors.white,
                                                    thumbShape: const RoundSliderThumbShape(
                                                      enabledThumbRadius: 6,
                                                    ),
                                                    overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                  ),
                                                  child: Slider(
                                                    value: _audioProgress,
                                                    onChanged: _seekAudio,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    // Current position
                                                    Text(
                                                      _formatDuration(_audioDuration != null
                                                          ? _audioProgress * _audioDuration!.inSeconds
                                                          : 0),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        color: Colors.white.withOpacity(0.7),
                                                      ),
                                                    ),
                                                    // Total duration
                                                    Text(
                                                      _formatDuration(_audioDuration?.inSeconds ?? 0),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        color: Colors.white.withOpacity(0.7),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Download button
                                          IconButton(
                                            icon: const Icon(Icons.download),
                                            color: Colors.white70,
                                            onPressed: _downloadAudio,
                                            tooltip: 'Download meditation',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Listen to your guided meditation',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.7),
                                          fontStyle: FontStyle.italic,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              
                              const SizedBox(height: 24),
                              
                              // Meditation script in dropdown
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                  ),
                                  child: ExpansionPanelList(
                                    elevation: 0,
                                    expandedHeaderPadding: EdgeInsets.zero,
                                    expansionCallback: (_, __) => _toggleScript(),
                                    children: [
                                      ExpansionPanel(
                                        backgroundColor: Colors.transparent,
                                        headerBuilder: (context, isExpanded) {
                                          return Container(
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.text_snippet_outlined,
                                                  color: Theme.of(context).colorScheme.primary,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Meditation Script',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        body: Container(
                                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                          child: Text(
                                            _meditation,
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              height: 1.8,
                                              color: Colors.white.withOpacity(0.9),
                                            ),
                                          ),
                                        ),
                                        isExpanded: _isScriptExpanded,
                                        canTapOnHeader: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 80),
                      
                      // Footer
                      Text(
                        '© 2025 Oneiro',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to build loading indicator with status
  Widget _buildLoadingIndicator() {
    // Always show a spinning indicator in the button
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  // Progress bar UI component with even padding
  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Equal padding above
        const SizedBox(height: 30),
        
        // Progress bar with percentage
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progressPercent > 0 ? _progressPercent / 100 : null,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  color: Theme.of(context).colorScheme.primary,
                  minHeight: 10,
                ),
              ),
            ),
            if (_progressPercent > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_progressPercent.round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        
        // Equal padding below
        const SizedBox(height: 30),
        
        // Status message
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Subtitle explaining the wait
        Text(
          'Creating your personalized meditation takes a bit of time. Please be patient...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// Helper method to format duration
String _formatDuration(num seconds) {
  final int mins = seconds ~/ 60;
  final int secs = seconds.toInt() % 60;
  return '$mins:${secs.toString().padLeft(2, '0')}';
}
