import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';

class HomePage extends StatefulWidget {
  @override
  _SmartLockHomeState createState() => _SmartLockHomeState();
}

class _SmartLockHomeState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  bool _isLocked = true;
  bool _isConnected = true;
  double _batteryLevel = 0.75;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      if (_isLocked) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildStatusBar(),
              Expanded(
                child: GestureDetector(
                  onTap: _toggleLock,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Transform.rotate(
                          angle: _rotationAnimation.value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _buildLockBody(),
                              _buildLockShackle(),
                              _buildParticleEffect(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // _buildControlPanel(),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.bluetooth,
                  color: _isConnected ? Colors.blue : Colors.grey, size: 20),
              SizedBox(width: 5),
              Text(
                _isConnected ? "Connected" : "Disconnected",
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.battery_std, color: Colors.black, size: 20),
              SizedBox(width: 5),
              Text(
                "${(_batteryLevel * 100).toInt()}%",
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLockBody() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: _isLocked ? Colors.redAccent : Colors.greenAccent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _isLocked
                ? Colors.redAccent.withOpacity(0.4)
                : Colors.greenAccent.withOpacity(0.4),
            blurRadius: 30,
            spreadRadius: 10,
          )
        ],
      ),
      child: Icon(
        _isLocked ? Icons.lock_outline : Icons.lock_open,
        size: 60,
        color: Colors.white,
      ),
    );
  }

  Widget _buildLockShackle() {
    return CustomPaint(
      painter: LockShacklePainter(isLocked: _isLocked),
      size: Size(200, 200),
    );
  }

  Widget _buildParticleEffect() {
    return AnimatedOpacity(
      opacity: _isLocked ? 0.0 : 1.0,
      duration: Duration(milliseconds: 300),
      child: Container(
        width: 200,
        height: 200,
        child: CustomPaint(
          painter: ParticlePainter(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class LockShacklePainter extends CustomPainter {
  final bool isLocked;

  LockShacklePainter({required this.isLocked});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (isLocked) {
      path.moveTo(size.width * 0.3, size.height * 0.2);
      path.quadraticBezierTo(size.width * 0.5, size.height * 0.1,
          size.width * 0.7, size.height * 0.2);
    } else {
      path.moveTo(size.width * 0.3, size.height * 0.2);
      path.quadraticBezierTo(size.width * 0.5, size.height * 0.1,
          size.width * 0.7, size.height * 0.2);
      path.moveTo(size.width * 0.7, size.height * 0.2);
      path.lineTo(size.width * 0.7, size.height * 0.4);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ParticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final random = Random();
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Random {
  static final _random = math.Random();

  static get math => null;

  double nextDouble() => _random.nextDouble();
}
