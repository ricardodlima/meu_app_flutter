import 'package:flutter/material.dart';

class AnimatedStateButton extends StatefulWidget {
  final String text;
  final Color activeColor;
  final VoidCallback onPressed;
  final bool isActive;
  final bool isBlinking;

  const AnimatedStateButton({
    Key? key,
    required this.text,
    required this.activeColor,
    required this.onPressed,
    this.isActive = false,
    this.isBlinking = false,
  }) : super(key: key);

  @override
  _AnimatedStateButtonState createState() => _AnimatedStateButtonState();
}

class _AnimatedStateButtonState extends State<AnimatedStateButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700), // Duração de um ciclo de piscar
    );

    // Definir a animação de cor
    _colorAnimation = ColorTween(
      begin: widget.activeColor.withOpacity(0.3), // Cor mais escura (inativo/base do piscar)
      end: widget.activeColor, // Cor ativa (pico do piscar)
    ).animate(_animationController);

    // Adicionar listener para reconstruir o widget durante a animação
    _animationController.addListener(() {
      setState(() {});
    });

    // Iniciar a animação se for para piscar
    if (widget.isBlinking) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedStateButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se o estado de piscar mudou
    if (widget.isBlinking != oldWidget.isBlinking) {
      if (widget.isBlinking) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
        _animationController.value = 0; // Resetar para a cor base
      }
    }
    // Se a cor ativa mudou (improvável neste caso, mas bom para robustez)
    if (widget.activeColor != oldWidget.activeColor) {
      _colorAnimation = ColorTween(
        begin: widget.activeColor.withOpacity(0.3),
        end: widget.activeColor,
      ).animate(_animationController);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color buttonColor;
    if (widget.isActive && widget.isBlinking) {
      // Se está ativo e piscando, usa a cor da animação
      buttonColor = _colorAnimation.value ?? widget.activeColor;
    } else if (widget.isActive && !widget.isBlinking) {
      // Se está ativo mas não piscando, usa a cor ativa
      buttonColor = widget.activeColor;
    } else {
      // Se não está ativo, usa uma cor escura
      buttonColor = Colors.grey[850]!; // Cor escura padrão para inativo
    }

    // Cor do texto
    Color textColor = widget.isActive ? Colors.white : Colors.grey;

    return GestureDetector(
      onTap: widget.onPressed,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.4, // Largura relativa
        height: 100, // Altura fixa para botões grandes
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: widget.isActive ? widget.activeColor.withOpacity(0.7) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (widget.isActive)
              BoxShadow(
                color: widget.activeColor.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Center(
          child: Text(
            widget.text,
            style: TextStyle(
              color: textColor,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}