const nodemailer = require('nodemailer');

function getTransporter() {
  return nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true' || parseInt(process.env.SMTP_PORT || '587', 10) === 465,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
}

async function sendOTP(email, otp) {
  const isProduction = process.env.NODE_ENV === 'production';
  const hasSmtpConfig = Boolean(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS);

  if (!hasSmtpConfig) {
    const isDevConsoleFallback = !isProduction && process.env.OTP_CONSOLE_FALLBACK === 'true';

    if (isDevConsoleFallback) {
      console.log('\n========================================');
      console.log(`🔐 [LawBuddy OTP Verification - Dev Mode Fallback]`);
      console.log(`📧 Target Email: ${email}`);
      console.log(`🔑 6-Digit OTP Code: ${otp}`);
      console.log('========================================\n');
      return { success: true, messageId: 'dev-mode-otp' };
    }

    console.warn('SMTP is not configured and OTP console fallback is disabled.');
    return { success: false, error: 'SMTP is not configured' };
  }

  try {
    const transporter = getTransporter();
    const info = await transporter.sendMail({
      from: process.env.SMTP_FROM || process.env.SMTP_USER,
      to: email,
      subject: 'Your LawBuddy Verification Code',
      html: `
        <div style="font-family: 'Inter', Arial, sans-serif; max-width: 600px; margin: 0 auto; background-color: #171218; padding: 40px; border-radius: 16px; border: 1px solid rgba(255,255,255,0.05); color: #ffffff;">
          <h1 style="color: #ffffff; margin-bottom: 24px; text-align: center; font-size: 28px;">LawBuddy</h1>
          <div style="background-color: #211c22; padding: 30px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.05);">
            <h2 style="color: #ffffff; margin-top: 0; font-size: 20px;">Verify Your Email</h2>
            <p style="color: #a0a0a0; font-size: 16px; line-height: 1.5;">Hello,</p>
            <p style="color: #a0a0a0; font-size: 16px; line-height: 1.5;">Your verification code is:</p>
            
            <div style="background-color: #171218; padding: 20px; border-radius: 8px; text-align: center; margin: 30px 0; border: 1px solid rgba(255,255,255,0.05);">
              <span style="font-size: 40px; font-weight: bold; letter-spacing: 8px; color: #6d28d9;">${otp}</span>
            </div>
            
            <p style="color: #a0a0a0; font-size: 14px; line-height: 1.5;">This code will expire in <strong>5 minutes</strong>.</p>
            <p style="color: #ef4444; font-size: 14px; line-height: 1.5; margin-top: 16px;"><strong>Security Warning:</strong> Never share this code with anyone. Our team will never ask for your password or OTP.</p>
          </div>
          
          <div style="margin-top: 30px; text-align: center;">
            <p style="color: #666666; font-size: 12px;">This is an automated email sent by LawBuddy. Please do not reply.</p>
          </div>
        </div>
      `
    });

    return { success: true, messageId: info.messageId };
  } catch (error) {
    const sanitizedError = error && error.message ? error.message : 'Unknown SMTP error';
    console.error(`Failed to send OTP email: ${sanitizedError}`);
    return { success: false, error: 'Failed to send OTP email' };
  }
}

module.exports = {
  sendOTP
};

