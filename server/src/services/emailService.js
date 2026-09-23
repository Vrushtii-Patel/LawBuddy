const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: parseInt(process.env.SMTP_PORT || '587', 10),
  secure: false, // true for 465, false for other ports
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

async function sendOTP(email, otp) {
  // If SMTP is not fully configured, log to console for instant developer convenience
  const hasSmtpConfig = process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS;

  if (!hasSmtpConfig) {
    console.log('\n========================================');
    console.log(`🔐 [LawBuddy OTP Verification]`);
    console.log(`📧 Target Email: ${email}`);
    console.log(`🔑 6-Digit OTP Code: ${otp}`);
    console.log('========================================\n');
    return { success: true, messageId: 'dev-mode-otp' };
  }

  try {
    const info = await transporter.sendMail({
      from: process.env.SMTP_FROM || '"LawBuddy" <finalyearproject2513@gmail.com>',
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
    console.error('SMTP Error sending OTP email:', error);
    console.log('\n========================================');
    console.log(`🔐 [LawBuddy OTP Fallback]`);
    console.log(`📧 Target Email: ${email}`);
    console.log(`🔑 6-Digit OTP Code: ${otp}`);
    console.log('========================================\n');
    return { success: true, messageId: 'fallback-otp' };
  }
}

module.exports = {
  sendOTP
};
