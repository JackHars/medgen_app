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
      // Send request to the backend server
      final response = await ApiService.processText(stressDescription);
      
      // Check if response contains a job ID
      if (response.containsKey('job_id')) {
        _jobId = response['job_id'];
        _startPollingJobStatus();
      } 
      // If we got an immediate response
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
      // If we got an error
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
                      if (_meditation.isNotEmpty) ...[
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
                                    children: [
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
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: LinearProgressIndicator(
                                                    value: _audioProgress,
                                                    backgroundColor: Theme.of(context).colorScheme.surface,
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      Theme.of(context).colorScheme.primary,
                                                    ),
                                                    minHeight: 8,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      _formatDuration(_audioProgress * 300), // 5 minutes in seconds
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        color: Colors.white.withOpacity(0.7),
                                                      ),
                                                    ),
                                                    Text(
                                                      '5:00',
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
                                          IconButton(
                                            icon: const Icon(Icons.download),
                                            color: Colors.white70,
                                            onPressed: _downloadAudio,
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
    if (_progressPercent <= 0) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            value: _progressPercent / 100,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_progressPercent.round()}%',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

// Helper method to format duration
String _formatDuration(double seconds) {
  final int mins = seconds ~/ 60;
  final int secs = seconds.toInt() % 60;
  return '$mins:${secs.toString().padLeft(2, '0')}';
}
