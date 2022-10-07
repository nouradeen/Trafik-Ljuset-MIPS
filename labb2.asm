```
# Mask for interrupt
.eqv EXT_INTTIME 0x400 # Mask for timerr interrupt (external), bit 10
.eqv EXT_INTBUTTON 0x800 # Mask for button interrupt (external), bit 11
.eqv EXCHMASK 0x003C # Mask for exceptions (internal), bits 2-6
.eqv CLEAR_ALL 0xFFFFF3FF # Mask for clearing time and button. Bits 10-11
.eqv CLEAR_BUTTON 0xFFFFF7FF # Mask for clearing just Button. Bit 11


# I/O
.eqv PEDESTRIANS_LIGHT 0xFFFF0010 # Walking light address
.eqv TRAFFIC_LIGHT 0xFFFF0011 # Traffic light address
.eqv BUTTONADDR 0xFFFF0013 # I/O button address
.eqv ENABLE_TIMER_ADR 0xFFFF0012 # I/O enabling timer
.eqv ENABLE_TIMER 0x01 # Mask for enabling timer

# Lights
.eqv PEDESTRIANS_STOP 0x01 # Stop for pedestrians light. Bit 0. Address: 0xFFFF0010
.eqv PEDESTRIANS_WALK 0x02 # Walk for pedestrians light. Bit 1. Address: 0xFFFF0010

.eqv DARK 0x00 # Dark color for pedestrians light. Address: 0xFFFF0010
.eqv RED 0x01 # Red color for traffic light. Bit 0. Address: 0xFFFF0011
.eqv ORANGE 0x02 # Orange color for traffic light. Bit 1. Address: 0xFFFF0011
.eqv GREEN 0x04 # Green color for traffic light. Bit 2. Address: 0xFFFF0011

# Mask for buttons value
.eqv WALK_BUTTON 0x01
.eqv DRIVE_BUTTON 0x02

	.ktext 0x80000180
	la $k0, int_routine
	jr $k0
	nop
	
	
.data
timer: .word 0
check_light: .word 0



.text
main:
	mfc0 $t0, $12	#Prepare status register for timer interrupt
	nop
	ori $t0, $t0, 1	# Enabale user interrupts
	ori $t0, $t0, EXT_INTTIME #Enable time interrupts
	nop
	
	ori $t0, $t0, EXT_INTBUTTON #Enable Button interrupts
	nop	
	mtc0 $t0, $12 # Set the new status register
	
	#Start the program with Traffic green light
	la $t0, TRAFFIC_LIGHT 
	add $a0, $zero, GREEN
	sb $a0, 0x0($t0)
	
	#Start the program with Pedestrian Stop
	la $t0, PEDESTRIANS_LIGHT
	add $a0, $zero, PEDESTRIANS_STOP
	sb $a0, 0x0($t0)
	
	la $t0, ENABLE_TIMER_ADR #Enable the timer
	add $a0, $zero, ENABLE_TIMER
	sb $a0, 0x0($t0)
	

loop:
	b loop	# Infinite loop
	
	li $v0, 10 #Exit
	syscall
	

	
int_routine:
	#Save all registers in the stack except $k0 and $k1
	subu $sp, $sp, 32
	sw $t0, 20($sp)
	sw $a0, 24($sp)
	sw $a1, 28($sp)
	
	mfc0 $k0, $13 #Set k0 to (cause)
	nop
	andi $t0, $k0, EXCHMASK # AND Gate, check if it (internal) Exception interrupt.
	bne $t0, $zero, goback #If Not Equal GOTO goback
	
	andi $t0, $k0, EXT_INTBUTTON # AND Gate, check if it (external) button interrupt
	bne $t0, $zero, int_button #If not Equal GOTO int_button
	
	andi $t0, $k0, EXT_INTTIME # AND Gate, check if it (external) timer interrupt
	bne $t0, $zero, int_timer # If not Equal GOTO int_timer
	

	

	
	j goback #No interrupts goback
	

int_button:
	la $t0, BUTTONADDR
	lb $a1, 0x0($t0)
	beq $a1, WALK_BUTTON, green_orange # Change from green to orange if button clicked
	beq $a1, DRIVE_BUTTON, red_orange # Change from red to orange if button clicked
	j goback
	


int_timer:
	lw $t0, timer
	addi $t0, $t0, 1 # Add 1 to timer each cycle
	sw $t0, timer

	
	beq $t0, 3, int_after_three # När timer blir 3, hoppar den till int_after_three och kollar om det finns orange på trafik ljuset, om True växlar den till Röd
	beq $t0, 10, int_after_ten #Traffic ljuset får inte ha grönt mer än 10 sekunder om någon person väntar
				   # Gångbanan får inte ha grönt mer än 10 sekunder oavsett.
	beq $t0, 13, int_after_thirteen # After 10 seconds green, if orange done with 3 seconds, reset everything to normal
	bge $t0, 7, int_after_seven #Gångbanan blir grönt i 7 sek, rött på vägen.Sedan växla till blinkande gubbe i 3 sek, sedan rött
	

	j goback
	
int_after_three:
	la $t0, TRAFFIC_LIGHT
	lb $a0, 0x0($t0)
	
	bne $a0, ORANGE, goback #If the road is orange, jump to (traffic_red)
	j traffic_red
	
traffic_red: #Turn the traffic light to red, and turn the walking light to green, and reset the timer
	la $t0, TRAFFIC_LIGHT
	lb $a0, 0x0($t0)
	
	bne $a0, ORANGE, goback # If TRAFFIC_LIGHT is not ORANGE, continue, else goback
	
	lw $t0, timer # Reset the timer
	li $t0, 0
	sw $t0, timer
	
	
	la $t0, TRAFFIC_LIGHT #Load the address of TRAFFIC_LIGHT
	add $a0, $zero, RED # Add the (red) bytes to $a0
	sb $a0, 0x0($t0) #Store the $a0 in the TRAFFIC_LIGHT to turn it to red
	
	la $t0, PEDESTRIANS_LIGHT #Load the address of PEDESTRIANS_LIGHT
	add $a0, $zero, PEDESTRIANS_WALK # Add the (walking sign) bytes to $a0
	sb $a0, 0x0($t0) # Store the $a0 in the PEDESTRIANS_LIGHT to turn it to the walking signal
	
	j goback
	
	

int_after_ten:
	lw $t0, check_light #check if the light is green or red
	beq $t0, 1, green_orange # if green, jump to green_orange
	
	la $t0, TRAFFIC_LIGHT
	lb $a0, 0x0($t0)
	beq $a0, RED, red_orange # If the road is red, jump to (traffic_orange)
	
	j goback
	
green_orange:
	lw $t0, check_light # Make the variable check_light to 1, it means the process of changing the light from green to orange is under execution
	li $t0, 1
	sw $t0, check_light
	
	lw $t0, timer
	
	blt $t0, 10, goback #If the timer did not reach 10 seconds, goback	
	

	li $t0, 0 # Reset the timer
	sw $t0, timer 
	
	
	la $t0, TRAFFIC_LIGHT # Make the TRAFFIC_LIGHT Orange
	add $a0, $zero, ORANGE
	sb $a0, 0x0($t0)
	
	la $t0, PEDESTRIANS_LIGHT # Male tje PEDESTRIANS_LIGHT to Stop
	add $a0, $zero, PEDESTRIANS_STOP
	sb $a0, 0x0($t0)
	
	lw $t0, check_light # The light change execution is done
	li $t0, 0
	sw $t0, check_light
	
	j goback
	
	
	
	
red_orange:
	lw $t0, timer
	

	blt $t0, 10, goback # if time less than 10, goback
	

	
	la $t0, TRAFFIC_LIGHT
	lb $a0, 0x0($t0)
	bne $a0, RED, goback # If traffic light is red, continue, else goback
	
	add $a0, $zero, ORANGE # Make the TRAFFIC_LIGHT Orange
	sb $a0, 0x0($t0)
	
	la $t0, PEDESTRIANS_LIGHT # Make the PEDESTRIANS_LIGHT to Stop sign
	add $a0, $zero, PEDESTRIANS_STOP
	sb $a0, 0x0($t0)
	
	j goback
	
	
	
	
	
	
	

int_after_seven:
	lw $t0, timer
	bge $t0, 10, goback # If time is more than or equal 10, goback

	
	la $t0, TRAFFIC_LIGHT
	lb $a0, 0x0($t0)
	bne $a0, RED, goback # If TRAFFIC_LIGHT is red continue, else goback
	
	la $t0, PEDESTRIANS_LIGHT
	lb $a0, 0x0($t0)
	
	beq $a0, DARK, blink # If PEDESTRIANS_LIGHT is red, jump to (blink)
	add $a0, $zero, DARK # Jump between dark and red to create the Blinking Red
	sb $a0, 0x0($t0)
	
	j goback
	
blink:
	la $t0, PEDESTRIANS_LIGHT
	add $a0, $zero, PEDESTRIANS_STOP
	sb $a0, 0x0($t0)
	
	j goback
	
	

int_after_thirteen: # 10 seconds for green, 3 seconds for orange
	la $t0, TRAFFIC_LIGHT
	lb $a0, 0x0($t0)
	bne $a0, ORANGE, goback # If TRAFFIC_LIGHT is not orange, goback
	
	j to_green
	
to_green:
	lw $t0, timer # Reset timer, start fresh
	li $t0, 0
	sw $t0, timer
	
	
	la $t0, TRAFFIC_LIGHT # Make TRAFFIC_LIGHT Green
	add $a0, $zero, GREEN
	sb $a0, 0x0($t0)
	
	la $t0, PEDESTRIANS_LIGHT # Make PEDESTRIANS_LIGHT Stop
	add $a0, $zero, PEDESTRIANS_STOP
	sb $a0, 0x0($t0)
	
	j goback
	
	
	
	
	







goback:
	#Restore the stack pointer
	mfc0 $k0, $13 # Kvittera interrupts
	nop
	andi $t0, $k0, CLEAR_BUTTON #Clear bits 10 (timer) and 11 (Button) from Cause resiger, set to zero
	mtc0 $t0, $13
	lw $t0, 20($sp)
	lw $a0, 24($sp)
	lw $a1, 28($sp)
	addu $sp, $sp, 32
	
	
	
	eret
```