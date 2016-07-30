import jenkins.model.* 
import com.cloudbees.plugins.credentials.* 
import com.cloudbees.plugins.credentials.common.* 
import com.cloudbees.plugins.credentials.domains.* 
import com.cloudbees.plugins.credentials.impl.* 
import com.cloudbees.jenkins.plugins.sshcredentials.impl.* 
import org.jenkinsci.plugins.plaincredentials.* 
import org.jenkinsci.plugins.plaincredentials.impl.* 
import hudson.util.Secret 
import hudson.plugins.sshslaves.* 
import org.apache.commons.fileupload.*  
import org.apache.commons.fileupload.disk.* 
import java.nio.file.Files 
import groovy.json.JsonSlurper

// Get Environment Variables
def env = System.getenv()
def jenkins_home = env['JENKINS_HOME']
def adop_gitlab_enabled = env['ADOP_GITLAB_ENABLED']
// File that contains the GitLab API Token
def gitlab_token_file = new File( jenkins_home+'/userContent/gitlab_api_token.txt' )

if(adop_gitlab_enabled == "true")
{
	// Wait till the file is created
	while ( !gitlab_token_file.exists() ) {
		println "Waiting for GitLab token to be available..."
		sleep(5000)
	}

	// Store the GitLab API Token to a variable
	String gitlab_token = gitlab_token_file.text

	// Constants
	domain = Domain.global() 
	store = Jenkins.instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

	// Secret Text for Gitlab
	gitlabToken = new StringCredentialsImpl( 
				CredentialsScope.GLOBAL, 
				"gitlab-secrets-id", 
				"Gitlab Root User Token used for Jenkins to Gitlab Connections.", 
				Secret.fromString(gitlab_token))

	// Store SecretText and UserPass
	store.addCredentials(domain, gitlabToken)
	
	// Create GitLab connection xml file
	def fileName = "com.dabsquared.gitlabjenkins.connection.GitLabConnectionConfig.xml"
	
	// Defining a file handler/pointer to handle the file.
	def gitlab_connection = new File(jenkins_home+ '/' + fileName)
	
	// Check if a file with same name exisits in the folder.
	//if(gitlab_connection.exists())
	//{
		// if a file exisits then it will print the message to the log.
		//println "A file named " + fileName + " already exisits in the same folder"
	//}
	//else
	//{
		//else it will create a file and write the GitLab connection xml 
		def gitlabxml = '''<?xml version='1.0' encoding='UTF-8'?>
<com.dabsquared.gitlabjenkins.connection.GitLabConnectionConfig plugin="gitlab-plugin@1.2.2">
  <connections>
    <com.dabsquared.gitlabjenkins.connection.GitLabConnection>
      <name>ADOP Gitlab</name>
      <url>http://gitlab/gitlab</url>
      <apiTokenId>gitlab-secrets-id</apiTokenId>
      <ignoreCertificateErrors>true</ignoreCertificateErrors>
    </com.dabsquared.gitlabjenkins.connection.GitLabConnection>
  </connections>
</com.dabsquared.gitlabjenkins.connection.GitLabConnectionConfig>'''
		gitlab_connection.write(gitlabxml)
	//}

}
else println "GitLab is disabled. Skipping GitLab Token Credentials creation."